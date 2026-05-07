import AppKit
import Foundation

/// Instala (o reinstala) la Quick Action "Convertir a Markdown con Marker"
/// dentro de ~/Library/Services/. macOS recoge automáticamente cualquier
/// .workflow que viva ahí, así que aparecerá en el menú de click derecho
/// de Finder sobre PDFs sin que el usuario tenga que tocar Automator.
@MainActor
enum QuickActionInstaller {
    private static let serviceFolderName = "Convertir a Markdown con Marker.workflow"
    private static let menuTitle = "Convertir a Markdown con Marker"

    static func installIfNeeded() {
        guard let cliURL = Bundle.main.url(forResource: "marker-cli", withExtension: nil) else {
            NSLog("[QuickActionInstaller] marker-cli no encontrado en el bundle")
            return
        }

        let cliPath = cliURL.path
        let serviceURL = userServicesURL().appendingPathComponent(serviceFolderName, isDirectory: true)
        let expectedCommand = commandString(cliPath: cliPath)

        if existingCommand(at: serviceURL) == expectedCommand {
            return // Ya está instalada y apunta al mismo binario.
        }

        do {
            try install(serviceURL: serviceURL, cliPath: cliPath)
            refreshServicesMenu()
            NSLog("[QuickActionInstaller] Quick Action instalada en \(serviceURL.path)")
        } catch {
            NSLog("[QuickActionInstaller] Falló la instalación: \(error)")
        }
    }

    // MARK: - Helpers

    private static func userServicesURL() -> URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return library.appendingPathComponent("Services", isDirectory: true)
    }

    private static func commandString(cliPath: String) -> String {
        // Invocamos vía `python3 <path>` (en vez de directo) para no depender
        // del bit ejecutable del archivo: Xcode al copiar resources al bundle
        // a veces lo descarta. El shebang del script queda como comentario
        // y el contenido se ejecuta igual.
        """
        export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
        python3 "\(cliPath)" "$@"
        """
    }

    private static func existingCommand(at serviceURL: URL) -> String? {
        let docURL = serviceURL.appendingPathComponent("Contents/document.wflow")
        guard
            let data = try? Data(contentsOf: docURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
            let actions = plist["actions"] as? [[String: Any]],
            let firstWrap = actions.first,
            let action = firstWrap["action"] as? [String: Any],
            let params = action["ActionParameters"] as? [String: Any],
            let cmd = params["COMMAND_STRING"] as? String
        else {
            return nil
        }
        return cmd
    }

    private static func install(serviceURL: URL, cliPath: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: serviceURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        if fm.fileExists(atPath: serviceURL.path) {
            try fm.removeItem(at: serviceURL)
        }

        let contentsURL = serviceURL.appendingPathComponent("Contents", isDirectory: true)
        try fm.createDirectory(at: contentsURL, withIntermediateDirectories: true)

        let infoData = try PropertyListSerialization.data(
            fromPropertyList: makeInfoPlist(),
            format: .xml,
            options: 0
        )
        try infoData.write(to: contentsURL.appendingPathComponent("Info.plist"))

        let docData = try PropertyListSerialization.data(
            fromPropertyList: makeDocumentPlist(cliPath: cliPath),
            format: .xml,
            options: 0
        )
        try docData.write(to: contentsURL.appendingPathComponent("document.wflow"))
    }

    private static func refreshServicesMenu() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/pbs")
        task.arguments = ["-update"]
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            // best effort — la Quick Action aparece igualmente al cabo de un rato
        }
    }

    // MARK: - Plist content

    private static func makeInfoPlist() -> [String: Any] {
        let service: [String: Any] = [
            "NSBackgroundColorName": "background",
            "NSIconName": "NSActionTemplate",
            "NSMenuItem": ["default": menuTitle],
            "NSMessage": "runWorkflowAsService",
            "NSRequiredContext": ["NSApplicationIdentifier": "com.apple.finder"],
            "NSSendFileTypes": ["com.adobe.pdf"],
        ]
        return ["NSServices": [service]]
    }

    private static func makeDocumentPlist(cliPath: String) -> [String: Any] {
        let action: [String: Any] = [
            "AMAccepts": [
                "Container": "List",
                "Optional": true,
                "Types": ["com.apple.cocoa.string"],
            ] as [String: Any],
            "AMActionVersion": "2.0.3",
            "AMApplication": ["Automator"],
            "AMParameterProperties": [
                "COMMAND_STRING": [String: Any](),
                "CheckedForUserDefaultShell": [String: Any](),
                "inputMethod": [String: Any](),
                "shell": [String: Any](),
                "source": [String: Any](),
            ] as [String: Any],
            "AMProvides": [
                "Container": "List",
                "Types": ["com.apple.cocoa.string"],
            ] as [String: Any],
            "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
            "ActionName": "Run Shell Script",
            "ActionParameters": [
                "COMMAND_STRING": commandString(cliPath: cliPath),
                "CheckedForUserDefaultShell": true,
                "inputMethod": 1, // 1 = pasar entrada como argumentos ("$@")
                "shell": "/bin/bash",
                "source": "",
            ] as [String: Any],
            "BundleIdentifier": "com.apple.RunShellScript",
            "CFBundleVersion": "2.0.3",
            "CanShowSelectedItemsWhenRun": false,
            "CanShowWhenRun": true,
            "Category": ["AMCategoryUtilities"],
            "Class Name": "RunShellScriptAction",
            "InputUUID": "3EC11A9F-81B9-420E-9DD7-18B74781092E",
            "Keywords": ["Shell", "Script", "Command", "Run", "Unix"],
            "OutputUUID": "294B5C0A-A498-49B7-95E7-E2CF4C0AD17B",
            "UUID": "F3DFC129-FAD1-4542-A61B-0451FE3BDE6B",
            "UnlocalizedApplications": ["Automator"],
            "arguments": [
                "0": ["default value": 0, "name": "inputMethod", "required": "0", "type": "0", "uuid": "0"] as [String: Any],
                "1": ["default value": false, "name": "CheckedForUserDefaultShell", "required": "0", "type": "0", "uuid": "1"] as [String: Any],
                "2": ["default value": "", "name": "source", "required": "0", "type": "0", "uuid": "2"] as [String: Any],
                "3": ["default value": "", "name": "COMMAND_STRING", "required": "0", "type": "0", "uuid": "3"] as [String: Any],
                "4": ["default value": "/bin/sh", "name": "shell", "required": "0", "type": "0", "uuid": "4"] as [String: Any],
            ] as [String: Any],
            "conversionLabel": 0,
            "isViewVisible": 1,
            "location": "314.750000:305.000000",
            "nibPath": "/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib",
        ]

        return [
            "AMApplicationBuild": "534",
            "AMApplicationVersion": "2.10",
            "AMDocumentVersion": "2",
            "actions": [["action": action, "isViewVisible": 1] as [String: Any]],
            "connectors": [String: Any](),
            "workflowMetaData": [
                "applicationBundleID": "com.apple.finder",
                "applicationBundleIDsByPath": ["/System/Library/CoreServices/Finder.app": "com.apple.finder"] as [String: Any],
                "applicationPath": "/System/Library/CoreServices/Finder.app",
                "applicationPaths": ["/System/Library/CoreServices/Finder.app"],
                "inputTypeIdentifier": "com.apple.Automator.fileSystemObject.PDF",
                "outputTypeIdentifier": "com.apple.Automator.nothing",
                "presentationMode": 15,
                "processesInput": false,
                "serviceApplicationBundleID": "com.apple.finder",
                "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
                "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObject.PDF",
                "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
                "serviceProcessesInput": false,
                "systemImageName": "NSActionTemplate",
                "useAutomaticInputType": false,
                "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
            ] as [String: Any],
        ]
    }
}
