import Foundation
import Supabase

enum AuthProviderKind {
    case apple
    case google
}

/// Supabase 認証を管理するサービス（Liftly と同じプロジェクトを使用）
@MainActor
@Observable
final class AuthService {
    private(set) var currentUserId: String?
    private(set) var currentUserEmail: String?
    private(set) var isSignedIn: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var activeSignInProvider: AuthProviderKind?
    private(set) var isDeletingAccount: Bool = false
    private(set) var error: String?

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
        Task { await restoreSession() }
    }

    // MARK: - Public

    /// Google OAuth でサインイン
    func signInWithGoogle() async {
        await signIn(provider: .google, activeProvider: .google)
    }

    /// Sign in with Apple でサインイン（Liftly と同じ OAuth ブラウザフロー）
    func signInWithApple() async {
        await signIn(provider: .apple, activeProvider: .apple)
    }

    /// Supabase 上のアカウントと同期データの削除を要求する。
    /// 実処理は Edge Function `delete-current-user` が現在の JWT を検証して行う。
    func deleteAccount() async {
        guard isSignedIn else { return }
        isDeletingAccount = true
        error = nil

        do {
            let session = try await client.auth.session
            client.functions.setAuth(token: session.accessToken)
            let _: DeleteAccountResponse = try await client.functions.invoke("delete-current-user")
            try? await client.auth.signOut()
            clearSession()
        } catch {
            self.error = error.localizedDescription
        }

        isDeletingAccount = false
    }

    private func signIn(provider: Provider, activeProvider: AuthProviderKind) async {
        guard !isLoading else { return }
        isLoading = true
        activeSignInProvider = activeProvider
        error = nil

        do {
            let session = try await client.auth.signInWithOAuth(
                provider: provider,
                redirectTo: SupabaseConfig.redirectURL
            )
            applySession(session)
        } catch {
            self.error = error.localizedDescription
        }

        activeSignInProvider = nil
        isLoading = false
    }

    /// サインアウト
    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            self.error = error.localizedDescription
        }
        clearSession()
    }

    /// セッションの復元（アプリ起動時に呼ばれる）
    func restoreSession() async {
        do {
            let session = try await client.auth.session
            currentUserId = session.user.id.uuidString
            currentUserEmail = session.user.email
            isSignedIn = true
        } catch {
            clearSession()
        }
    }

    /// ディープリンクからのコールバック処理
    func handleDeepLink(_ url: URL) async {
        do {
            try await client.auth.session(from: url)
            await restoreSession()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func clearSession() {
        currentUserId = nil
        currentUserEmail = nil
        isSignedIn = false
    }

    private func applySession(_ session: Session) {
        currentUserId = session.user.id.uuidString
        currentUserEmail = session.user.email
        isSignedIn = true
    }

}

private struct DeleteAccountResponse: Decodable {
    let deleted: Bool?
}
