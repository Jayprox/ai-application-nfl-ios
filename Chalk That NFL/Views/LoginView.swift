//
//  LoginView.swift
//  Chalk That NFL
//
//  Username + password — matches backend-api's actual login convention
//  (no email option). Styled directly off the Stadium Lights tokens in
//  Extensions/Color+Brand.swift; no hardcoded hex values here.
//
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel

    @State private var username = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case username, password
    }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    header

                    VStack(spacing: 14) {
                        field(
                            title: "Username",
                            text: $username,
                            isSecure: false,
                            contentType: .username,
                            field: .username
                        )
                        field(
                            title: "Password",
                            text: $password,
                            isSecure: true,
                            contentType: .password,
                            field: .password
                        )
                    }

                    if let errorMessage = auth.errorMessage {
                        Text(errorMessage)
                            .font(.brandBody(14, weight: .medium))
                            .foregroundStyle(Color.negative)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        focusedField = nil
                        Task { await auth.login(username: username, password: password) }
                    } label: {
                        ZStack {
                            if auth.isLoading {
                                ProgressView()
                                    .tint(Color.onAccent)
                            } else {
                                Text("Log In")
                                    .font(.brandBody(16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .background(Color.accent)
                    .foregroundStyle(Color.onAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .disabled(auth.isLoading || username.isEmpty || password.isEmpty)
                    .opacity((username.isEmpty || password.isEmpty) ? 0.6 : 1)
                }
                .padding(24)
                .frame(maxWidth: 420)
                .padding(.top, 60)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("CHALK THAT")
                .font(.brandDisplay(28, weight: .semibold))
                .foregroundStyle(Color.ink)
            Text("NFL")
                .font(.brandDisplay(28, weight: .semibold))
                .foregroundStyle(Color.inkFaint)
        }
        .textCase(.uppercase)
        .tracking(1.5)
    }

    private func field(
        title: String,
        text: Binding<String>,
        isSecure: Bool,
        contentType: UITextContentType,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.brandBody(13, weight: .medium))
                .foregroundStyle(Color.inkFaint)

            Group {
                if isSecure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .textContentType(contentType)
            .focused($focusedField, equals: field)
            .font(.brandBody(16))
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(focusedField == field ? Color.accent : Color.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
