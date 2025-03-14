<div id="auth-container" class="auth-container">
    <div class="auth-box">
        <div class="auth-header">
            <h1>Forgot Password</h1>
            <p>Enter your email address and we'll send you a link to reset your password.</p>
        </div>
        <div id="error-message" class="error-message"></div>
        <form class="auth-form"
            hx-post="/auth/forgot_password"
            hx-trigger="submit"
            hx-target="#error-message"
            hx-swap="innerHTML"
            hx-indicator="#loading">
            <div class="form-group">
                <div class="input-wrapper">
                    <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2z"/>
                        <path d="M2 8l10 5 10-5"/>
                    </svg>
                    <input type="email" id="email" name="email" placeholder="Enter your email" required>
                </div>
            </div>
            <div id="loading" class="htmx-indicator">
                Loading...
            </div>
            <button type="submit" class="button">Send Reset Link</button>
        </form>
        <div class="auth-footer">
            <p>Remember your password?
                <a href="/auth/login">Sign in
                </a>
            </p>
        </div>

    </div>
</div>

<script>
    const errorMessageContainer = document.querySelector('#error-message');
    const authForm = document.querySelector('.auth-form');

    const handleResponseError = (event) => {
        const { xhr } = event.detail;

        switch (xhr.status) {
            case 422:
                errorMessageContainer.innerHTML = "Please provide your email address.";
                break;
            case 500:
            default:
                errorMessageContainer.innerHTML = "An unexpected error occurred. Please try again later.";
                break;
        }
    };

    const handleAfterRequest = (event) => {
        const { xhr } = event.detail;
        if (xhr.status === 201) {
            errorMessageContainer.innerHTML = "If that email address is in our system, we have sent a password reset link.  Wait.., no email system made yet. check debug log for the reset_url.";
        }
    };

    const handleSubmit = (event) => {
        errorMessageContainer.innerHTML = "";
    };

    document.body.addEventListener('htmx:responseError', handleResponseError);
    document.body.addEventListener('htmx:afterRequest', handleAfterRequest);
    authForm.addEventListener('submit', handleSubmit);

</script>
