import SwiftUI
import FirebaseAuth


struct AuthView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var login = ""
    @State private var isLogin = true

    var body: some View {
        VStack(spacing: 20) {
            Text(isLogin ? "auth_login".localized : "auth_register".localized)
                .font(.largeTitle)
                .bold()

            if !isLogin {
                TextField("auth_login_field".localized, text: $login)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            TextField("auth_email".localized, text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)

            SecureField("auth_password".localized, text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button(action: {
                if isLogin {
                    auth.login(email: email, password: password)
                } else {
                    auth.register(email: email, password: password, login: login)
                }
            }) {
                Text(isLogin ? "auth_login".localized : "auth_register".localized)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            if !auth.errorMessage.isEmpty {
                Text(auth.errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top)
            }
            // 🔁 Кнопка-переключатель
                        Button(action: {
                            isLogin.toggle()
                            auth.errorMessage = ""
                        }) {
                Text(isLogin ? "auth_no_account".localized : "auth_have_account".localized)
                                .foregroundColor(.blue)
                                .font(.footnote)
                        }
                    }
        .padding()
        .onAppear {
            auth.errorMessage = ""
        }
    }
}
