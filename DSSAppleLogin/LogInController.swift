//
//  LogInController.swift
//  DSSAppleLogin
//
//  Created by David Quispe Aruquipa on 30/09/22.
//

import UIKit
import ParseSwift
import AuthenticationServices

class LogInController: UIViewController {
    private let usernameTextField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.placeholder = "Username *"
        textField.autocapitalizationType = .none
        textField.textAlignment = .center
        return textField
    }()
    
    private let passwordTextField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.isSecureTextEntry = true
        textField.placeholder = "Password *"
        textField.textAlignment = .center
        return textField
    }()
    
    private let logInButton: UIButton = {
        let button = UIButton(type: .roundedRect)
        button.setTitle("Log in", for: .normal)
        return button
    }()
    
    private let signInWithAppleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: "appleIcon"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Back4App Log In"
        
        // Lays out the login form
        let stackView = UIStackView(arrangedSubviews: [usernameTextField, passwordTextField, logInButton])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 8
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        
        let stackViewHeight = CGFloat(stackView.arrangedSubviews.count) * (44 + stackView.spacing) - stackView.spacing
        
        view.addSubview(stackView)
        stackView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor).isActive = true
        stackView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.7).isActive = true
        stackView.heightAnchor.constraint(equalToConstant: stackViewHeight).isActive = true
        
        // Social media sign in buttons
        let buttonsStackViewHeight: CGFloat = 50
        let buttonsStackView = UIStackView(arrangedSubviews: [signInWithAppleButton])
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        buttonsStackView.spacing = 8
        buttonsStackView.axis = .horizontal
        buttonsStackView.distribution = .fillEqually
        
        view.addSubview(buttonsStackView)
        buttonsStackView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
        buttonsStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12).isActive = true
        buttonsStackView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.7).isActive = true
        buttonsStackView.heightAnchor.constraint(equalToConstant: buttonsStackViewHeight).isActive = true
        
        // "Sign in with" label
        let signInWithLabel = UILabel()
        signInWithLabel.text = "Or sign in with"
        signInWithLabel.textAlignment = .center
        signInWithLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(signInWithLabel)
        signInWithLabel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
        signInWithLabel.bottomAnchor.constraint(equalTo: buttonsStackView.topAnchor, constant: -12).isActive = true
        signInWithLabel.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.7).isActive = true
        
        // Adds the method that will be called when the user taps the login button
        logInButton.addTarget(self, action: #selector(handleLogIn), for: .touchUpInside)
        
        // Handlers for the social media sign in buttons
        signInWithAppleButton.addTarget(self, action: #selector(handleSignInWithApple), for: .touchUpInside)
        
        // If the user is already logged in, we redirect them to the HomeController
        guard let user = User.current else { return }
        let homeController = HomeController()
        homeController.user = user
        
        navigationController?.pushViewController(homeController, animated: true)
    }
    
    /// Called when the user taps on the singInButton button
    @objc private func handleLogIn() {
        guard let username = usernameTextField.text, !username.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            // Shows an alert with the appropriate title and message.
            return showMessage(title: "Error", message: "Invalid credentials.")
        }
        
        logIn(with: username, password: password)
    }
    
    /// Logs in the user and presents the app's home screen (HomeController)
    /// - Parameters:
    ///   - username: User's username
    ///   - password: User's password
    private func logIn(with username: String, password: String) {
        // Logs in the user asynchronously
        User.login(username: username, password: password) { [weak self] result in
            switch result {
            case .success(let loggedInUser):
                self?.usernameTextField.text = nil
                self?.passwordTextField.text = nil

                // After the login success we send the user to the home screen
                let homeController = HomeController()
                homeController.user = loggedInUser

                self?.navigationController?.pushViewController(homeController, animated: true)
            case .failure(let error):
                self?.showMessage(title: "Error", message: "Failed to log in: \(error.message)")
            }
        }
    }
}

// MARK: - Sign in with Apple section
extension LogInController: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @objc fileprivate func handleSignInWithApple() {
        // As requested by apple, we set up the necessary objects to implement the sign in with Apple flow.
        // See https://help.apple.com/developer-account/#/devde676e696 for more details
        let provider = ASAuthorizationAppleIDProvider()
        let request: ASAuthorizationAppleIDRequest = provider.createRequest()
        
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        
        // Presents the sign in with Apple sheet and the result will be handled by the ASAuthorizationControllerDelegate delegate
        authorizationController.performRequests()
    }
    
    // ASAuthorizationControllerDelegate
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        // We cast the (ASAuthorization) authorization object to an ASAuthorizationAppleIDCredential object
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return showMessage(title: "Sign in with Apple", message: "Invalid credential")
        }
        
        guard let identityToken = credential.identityToken else {
            return showMessage(title: "Sign in with Apple", message: "Token not found")
        }
        
        // We log in the user with the token generated by Apple
        User.apple.login(user: credential.user, identityToken: identityToken) { [weak self] result in
            switch result {
            case .success(let user):
                // After the login succeeded, we send the user to the home screen
                // Additionally, you can complete the user information with the data provided by Apple
                let homeController = HomeController()
                homeController.user = user
                
                self?.navigationController?.pushViewController(homeController, animated: true)
            case .failure(let error):
                self?.showMessage(title: "Error", message: error.message)
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        showMessage(title: "Error", message: error.localizedDescription)
    }
    
    // ASAuthorizationControllerPresentationContextProviding
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let window = view.window else { fatalError("No UIWindow found!") }
        return window
    }
}

// MARK: - Helpers
extension UIViewController {
    
    /// Presents an alert with a title, a message and a back button.
    /// - Parameters:
    ///   - title: Title for the alert
    ///   - message: Shor message for the alert
    func showMessage(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Back", style: .cancel))
        
        present(alertController, animated: true)
    }
}
