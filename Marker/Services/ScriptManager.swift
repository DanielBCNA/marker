import Foundation

enum ScriptError: LocalizedError {
    case scriptNotFound
    case missingAPIKey
    case missingPython
    case nonZeroExit(code: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .scriptNotFound:
            return "convert.py no se encontró en el bundle."
        case .missingAPIKey:
            return "Falta GEMINI_API_KEY (configúrala en Settings)."
        case .missingPython:
            return "No se encontró python3 en /opt/homebrew/bin, /usr/local/bin ni /usr/bin."
        case .nonZeroExit(_, let stderr):
            let cleaned = ScriptError.stripPythonNoise(stderr)
            return cleaned.isEmpty ? "Error desconocido" : cleaned
        }
    }

    private static func stripPythonNoise(_ stderr: String) -> String {
        // Filtra líneas de FutureWarning/DeprecationWarning de imports, que son
        // ruido y no el error real (especialmente con Python 3.9 EOL).
        let noisePatterns = [
            "FutureWarning",
            "DeprecationWarning",
            "NotOpenSSLWarning",
            "warnings.warn(",
        ]
        let lines = stderr.split(separator: "\n", omittingEmptySubsequences: false)
        let filtered = lines.filter { line in
            !noisePatterns.contains(where: line.contains)
        }
        return filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ScriptManager {
    func convert(
        input: URL,
        output: URL,
        onStart: (@MainActor (Process) -> Void)? = nil
    ) async throws {
        guard let scriptURL = Bundle.main.url(forResource: "convert", withExtension: "py") else {
            throw ScriptError.scriptNotFound
        }
        guard let apiKey = loadAPIKey() else {
            throw ScriptError.missingAPIKey
        }
        guard let python = locatePython() else {
            throw ScriptError.missingPython
        }

        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try await runProcess(
            executable: python,
            args: [scriptURL.path, input.path, output.path],
            env: ["GEMINI_API_KEY": apiKey],
            onStart: onStart
        )
    }

    // MARK: - API key resolution

    private func loadAPIKey() -> String? {
        if let key = APIKeySource.current() {
            return key
        }
        let configPath = ("~/.config/marker/api_key" as NSString).expandingTildeInPath
        if let key = try? String(contentsOfFile: configPath, encoding: .utf8) {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return readDotEnvKey()
    }

    private func readDotEnvKey() -> String? {
        // En desarrollo (cuando se ejecuta desde Xcode), el cwd suele ser
        // la raíz del repo o DerivedData. Buscamos hacia arriba.
        let fm = FileManager.default
        var dir = URL(fileURLWithPath: fm.currentDirectoryPath)
        for _ in 0..<5 {
            let candidate = dir.appendingPathComponent(".env")
            if let contents = try? String(contentsOf: candidate, encoding: .utf8) {
                for line in contents.split(separator: "\n") {
                    let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                    if parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces) == "GEMINI_API_KEY" {
                        let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                        if !value.isEmpty { return value }
                    }
                }
            }
            dir.deleteLastPathComponent()
        }
        return nil
    }

    // MARK: - Python resolution

    private func locatePython() -> String? {
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // MARK: - Process

    private func runProcess(
        executable: String,
        args: [String],
        env: [String: String],
        onStart: (@MainActor (Process) -> Void)?
    ) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args

        var processEnv = ProcessInfo.processInfo.environment
        processEnv["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        processEnv["PYTHONWARNINGS"] = "ignore"
        for (key, value) in env { processEnv[key] = value }
        process.environment = processEnv

        let stderrPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = stdoutPipe

        // Hop a MainActor antes de arrancar para que ConversionStore registre
        // el Process en su map. Una vez registrado, el botón cancelar puede
        // llamar terminate() en cualquier momento.
        if let onStart {
            await MainActor.run { onStart(process) }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                let stderr = String(
                    data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ScriptError.nonZeroExit(
                        code: proc.terminationStatus, stderr: stderr
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
