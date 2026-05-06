import AppKit
import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private var hasRequestedAuthorization = false
    private var isAuthorized = false

    private init() {}

    func requestAuthorizationIfNeeded() async {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        do {
            isAuthorized = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            isAuthorized = false
        }
    }

    /// Envía una notificación con el resumen del lote, sólo si la app no es
    /// la ventana en primer plano. Si el usuario está mirando Marker, las
    /// filas ya muestran los estados — la notificación sería ruido.
    func notifyBatchComplete(succeeded: Int, failed: Int) async {
        guard !NSApp.isActive else { return }

        await requestAuthorizationIfNeeded()
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Marker"
        content.body = bodyText(succeeded: succeeded, failed: failed)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func bodyText(succeeded: Int, failed: Int) -> String {
        switch (succeeded, failed) {
        case (0, 0):
            return "Lote terminado"
        case (let s, 0) where s == 1:
            return "1 PDF convertido"
        case (let s, 0):
            return "\(s) PDFs convertidos"
        case (0, let f) where f == 1:
            return "1 PDF falló"
        case (0, let f):
            return "\(f) PDFs fallaron"
        case (let s, let f):
            return "\(s) convertidos · \(f) fallaron"
        }
    }
}
