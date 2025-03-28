<section id="auth-container" class="auth-container">
    <div class="auth-box">
        <div id="error-message" class="error-message"></div>
        <div class="auth-header">
            @partial libs/components/brand
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
                <input type="email" id="email" name="email" placeholder="Enter your email" required>
            </div>
            <div class="form-group">
                <input type="password" id="password" name="password" placeholder="Enter your password" required>
            </div>
            <div class="form-group">
                <input type="password" id="password_confirm" name="password_confirm" placeholder="Confirm your password" required>
            </div>
            <div class="form-group">
                <input type="text" id="username" name="username" placeholder="Enter your username" required>
            </div>


            <div id="loading" class="htmx-indicator">
                Loading...
            </div>

            @partial libs/components/btn_submit("Sign Up")
        </form>

        <div class="auth-footer">
            <p>Already have an account?
                <a href="/auth/login" hx-boost="true">Sign in
                </a>
            </p>
        </div>
    </div>
</section>
