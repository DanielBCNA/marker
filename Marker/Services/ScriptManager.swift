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
            return "Falta GEMINI_API_KEY (env var, ~/.config/marker/api_key, o .env)."
        case .missingPython:
            return "No se encontró python3 en /opt/homebrew/bin, /usr/local/bin ni /usr/bin."
        case .nonZeroExit(_, let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Error desconocido" : trimmed
        }
    }
}

struct ScriptManager {
    func convert(input: URL, output: URL) async throws {
        guard let scriptURL = Bundle.main.url(forResource: "convert", withExtension: "py") else {
            throw ScriptError.scriptNotFound
        }
        guard let apiKey = loadAPIKey() else {
            throw ScriptError.missingAPIKey
        }
        guard let python = locatePython() else {
            throw ScriptError.missingPython
        }

        try await runProcess(
            executable: python,
            args: [scriptURL.path, input.path, output.path],
            env: ["GEMINI_API_KEY": apiKey]
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

    private func runProcess(executable: String, args: [String], env: [String: String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args

            var processEnv = ProcessInfo.processInfo.environment
            processEnv["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            for (key, value) in env { processEnv[key] = value }
            process.environment = processEnv

            let stderrPipe = Pipe()
            let stdoutPipe = Pipe()
            process.standardError = stderrPipe
            process.standardOutput = stdoutPipe

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
