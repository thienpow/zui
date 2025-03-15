<section id="auth-container" class="auth-container">
    <div class="auth-box">
        <div id="error-message" class="error-message"></div>
        <div class="auth-header">
            @partial libs/components/brand
            <p class="subtitle">Please enter your credentials to sign in</p>
        </div>
        <!--  -->
        <form class="auth-form"
            hx-post="/auth/login"
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

            <div class="form-group">
                <div class="input-wrapper">
                    <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
                        <path d="M7 11V7a5 5 0 0110 0v4"/>
                    </svg>
                    <input type="password" id="password" name="password" placeholder="Enter your password" required>
                </div>
            </div>

            <div id="loading" class="htmx-indicator">
                Loading...
            </div>

            <div class="form-group">
                <label class="checkbox-container">
                    <input type="checkbox" id="remember" name="remember">
                    <span class="checkmark"></span>
                    <span>Remember me</span>
                </label>
            </div>

            @partial libs/components/btn_submit("Sign In")
        </form>

        <div class="auth-footer">
            <p>Don't have an account?
                <a href="/auth/register" hx-boost="true">Sign up
                </a>
            </p>
            <p>Or,
                <a href="/auth/forgot_password" hx-boost="true">Forgot Password?
                </a>
            </p>
        </div>

        <div class="oauth-providers">
            <h3>Or sign in with:</h3>

            <a href="/auth/oauth/login?provider=google" class="btn-submit btn-google">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="20" height="20">
                    <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                    <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                    <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z"/>
                    <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
                </svg>
                Sign in with Google
            </a>
            <br/>

            <a href="/auth/oauth/login?provider=github" class="btn-submit btn-github">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="20" height="20">
                    <path fill="#181717" d="M12 1.27a11 11 0 00-3.48 21.46c.55.1.75-.24.75-.53v-1.86c-3.06.67-3.7-1.47-3.7-1.47-.5-1.27-1.22-1.6-1.22-1.6-1-.68.08-.67.08-.67 1.1.08 1.68 1.13 1.68 1.13.98 1.68 2.57 1.2 3.2.91.1-.7.38-1.2.7-1.47-2.45-.28-5.02-1.22-5.02-5.43 0-1.2.43-2.18 1.13-2.95-.11-.28-.49-1.4.11-2.9 0 0 .92-.3 3.02 1.12a10.49 10.49 0 015.5 0c2.1-1.42 3.02-1.12 3.02-1.12.6 1.51.22 2.63.1 2.9.7.77 1.13 1.75 1.13 2.95 0 4.22-2.57 5.15-5.03 5.42.4.34.75 1.01.75 2.04v3.03c0 .29.2.63.76.52A11 11 0 0012 1.27"/>
                </svg>
                Sign in with GitHub
            </a>
        </div>
    </div>
</section>
