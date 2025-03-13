<div class="auth-container">
    <div class="auth-box">
        <div class="auth-header">
            <h1>Reset Password</h1>
            <p>Enter your new password.</p>
        </div>
         <div id="error-message" class="error-message"></div>
        <form class="auth-form"
            hx-post="/auth/reset_password"
            hx-trigger="submit"
            hx-target="#error-message"
            hx-swap="innerHTML"
            hx-indicator="#loading"
        >
            <input type="hidden" name="token" value="{{.token}}">
            <div class="form-group">
                <div class="input-wrapper">
                    <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
                        <path d="M7 11V7a5 5 0 0110 0v4"/>
                    </svg>
                    <input type="password" id="password" name="password" placeholder="New Password" required>
                </div>
            </div>
             <div class="form-group">
                <div class="input-wrapper">
                    <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
                        <path d="M7 11V7a5 5 0 0110 0v4"/>
                    </svg>
                    <input type="password" id="password_confirm" name="password_confirm" placeholder="Confirm New Password" required>
                </div>
            </div>
            <div id="loading" class="htmx-indicator">
                Loading...
            </div>
            <button type="submit" class="button">Reset Password</button>
        </form>
        <div class="auth-footer">
             <p>Remember your password? <a href="/auth/login" hx-boost="true">Sign in</a></p>
        </div>
    </div>
</div>

@partial libs/styles/auth

<script>
    document.body.addEventListener('htmx:responseError', (event) => {
        const { xhr } = event.detail;
        const errorMessageContainer = document.querySelector('#error-message');

        switch (xhr.status) {
            case 400:
                errorMessageContainer.innerHTML = "Password does not match, weak, or bad.";
                break;
            case 401:
                errorMessageContainer.innerHTML = "Invalid or expired token. Please try again or request a new password reset link.";
                break;
            case 422:
                errorMessageContainer.innerHTML = "Please enter a new password";
            case 500:
            default:
                errorMessageContainer.innerHTML = "An unexpected error occurred. Please try again later.";
                break;
        }
    });
</script>
