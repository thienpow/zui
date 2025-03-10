<div class="auth-container">
    <div class="auth-box">
        <div id="error-message" class="error-message"></div>
        <div class="auth-header">
            <div class="logo">
                <svg class="logo-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
                </svg>
                <span class="logo-text">zUI Portal</span>
            </div>
            <h1>Welcome!</h1>
            <p class="subtitle">Create your account to get started</p>
        </div>

        <form class="auth-form"
            hx-post="/auth/register"
            hx-trigger="submit"
            hx-target="#error-message"
            hx-swap="innerHTML"
            hx-indicator="#loading">

            <div class="form-group">
                <input type="text" id="username" name="username" placeholder="Enter your username" required>
            </div>
            <div class="form-group">
                <input type="email" id="email" name="email" placeholder="Enter your email" autocomplete="email" required>
            </div>
            <div class="form-group">
                <input type="password" id="password" name="password" placeholder="Enter your password" autocomplete="new-password" required>
            </div>
            <div class="form-group">
                <input type="password" id="password_confirmation" name="password_confirmation" placeholder="Confirm your password" autocomplete="new-password" required>  <!-- Added password confirmation -->
            </div>


            <div id="loading" class="htmx-indicator">
                Loading...
            </div>

            <button type="submit" class="button" aria-label="Sign Up">
                <span>Sign Up</span>
                <svg class="button-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M14 5l7 7m0 0l-7 7m7-7H3"/>
                </svg>
            </button>
        </form>

        <div class="auth-footer">
            <p>Already have an account? <a href="/auth/login"
               hx-boost="true"
               hx-target=".auth-container"
               hx-swap="innerHTML">Sign in</a></p>
        </div>
    </div>
</div>

@partial libs/styles/auth

<script>
    document.querySelector('.auth-form').addEventListener('submit', (event) => {
        const errorMessageContainer = document.querySelector('#error-message');
        errorMessageContainer.innerHTML = "";
    });

    document.body.addEventListener('htmx:responseError', (event) => {
        const { xhr } = event.detail;
        if (xhr.status === 422) { // Validation errors
            const errorMessageContainer = document.querySelector('#error-message');
            // Assuming server sends back JSON with error messages
            try {
                const errors = JSON.parse(xhr.responseText);
                errorMessageContainer.innerHTML = errors.message || Object.values(errors).join("<br>"); // Display general message or individual field errors
            } catch (e) {
                errorMessageContainer.innerHTML = "An error occurred during registration. Please try again.";
            }

        } else if (xhr.status === 400) { // Other error
            const errorMessageContainer = document.querySelector('#error-message');
            errorMessageContainer.innerHTML = xhr.responseText; // Display other server side error
        }
    });

    document.body.addEventListener('htmx:afterRequest', (event) => {
        const { xhr } = event.detail;
         if (xhr.responseText.trim() === "success") {
            window.location.href = "/auth/login"; //
        }
    });

</script>
