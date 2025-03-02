
<style>
    .htmx-indicator {
        display: none;
        text-align: center;
        padding: 10px;
        color: var(--color-text-primary);
    }
    .htmx-request .htmx-indicator {
        display: block;
    }
    .htmx-request.auth-button {
        opacity: 0.5;
        pointer-events: none;
    }
    .error-message {
        display: none;
        background-color: #fee2e2;
        border: 1px solid #fecaca;
        color: #dc2626;
        padding: 12px;
        border-radius: 8px;
        margin-bottom: 20px;
        text-align: center;
        font-size: 14px;
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        z-index: 10;
    }
    .error-message:not(:empty) {
      display: block;
      animation: fadeIn 0.3s ease-in-out;
    }
    @keyframes fadeIn {
        from { opacity: 0; transform: translateY(-10px); }
        to { opacity: 1; transform: translateY(0); }
    }

    .auth-container {
        min-height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 24px;
        background: #f8fafc;
    }

    .auth-box {
        width: 100%;
        max-width: 420px;
        background: white;
        border-radius: 16px;
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1),
                    0 2px 4px -1px rgba(0, 0, 0, 0.06);
        padding: 40px;
    }

    .auth-header {
        text-align: center;
        margin-bottom: 32px;
    }

    .logo {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        margin-bottom: 24px;
    }

    .logo-icon {
        width: 32px;
        height: 32px;
        color: var(--color-text-primary);
    }

    .logo-text {
        font-size: 24px;
        font-weight: 600;
        color: var(--color-text-primary);
    }

    .auth-header h1 {
        font-size: 24px;
        font-weight: 600;
        color: var(--color-text-primary);
        margin: 0 0 8px 0;
    }

    .subtitle {
        color: var(--color-text-primary);
        opacity: 0.6;
        margin: 0;
    }

    .auth-form {
        display: flex;
        flex-direction: column;
        gap: 24px;
    }

    .form-group {
        display: flex;
        flex-direction: column;
        gap: 8px;
    }
    .form-group .error-text {
        color: #dc2626;
        font-size: 12px;
        margin-top: 4px;
    }
    .password-label {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    label {
        font-size: 14px;
        font-weight: 500;
        color: var(--color-text-primary);
    }

    .forgot-password {
        font-size: 14px;
        color: var(--color-text-primary);
        text-decoration: none;
        opacity: 0.8;
        transition: opacity 0.2s;
    }

    .forgot-password:hover {
        opacity: 1;
    }

    .input-wrapper {
        position: relative;
        display: flex;
        align-items: center;
    }

    .input-icon {
        position: absolute;
        left: 12px;
        width: 20px;
        height: 20px;
        color: var(--color-text-primary);
        opacity: 0.4;
    }
    input:invalid {
        border-color: #dc2626;
    }
    input[type="text"],
    input[type="email"],
    input[type="password"] {
        width: 100%;
        padding: 12px 12px 12px 44px;
        border: 1px solid #e2e8f0;
        border-radius: 8px;
        font-size: 15px;
        transition: all 0.2s;
    }

    input[type="text"]:focus,
    input[type="email"]:focus,
    input[type="password"]:focus {
        outline: none;
        border-color: var(--color-text-primary);
        box-shadow: 0 0 0 3px rgba(66, 153, 225, 0.1);
    }

    .toggle-password {
        position: absolute;
        right: 12px;
        background: none;
        border: none;
        padding: 0;
        cursor: pointer;
        color: var(--color-text-primary);
        opacity: 0.4;
        transition: opacity 0.2s;
    }

    .toggle-password:hover {
        opacity: 0.8;
    }

    .eye-icon {
        width: 20px;
        height: 20px;
    }

    .checkbox-container {
        display: flex;
        align-items: center;
        gap: 8px;
        cursor: pointer;
        user-select: none;
    }

    .checkbox-container input {
        display: none;
    }

    .checkmark {
        width: 18px;
        height: 18px;
        border: 2px solid #e2e8f0;
        border-radius: 4px;
        position: relative;
        transition: all 0.2s;
    }

    .checkbox-container input:checked + .checkmark {
        background: var(--color-text-primary);
        border-color: var(--color-text-primary);
    }

    .checkbox-container input:checked + .checkmark:after {
        content: "";
        position: absolute;
        left: 5px;
        top: 2px;
        width: 4px;
        height: 8px;
        border: solid white;
        border-width: 0 2px 2px 0;
        transform: rotate(45deg);
    }

    .auth-button {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        width: 100%;
        padding: 12px;
        background: var(--color-text-primary);
        color: white;
        border: none;
        border-radius: 8px;
        font-size: 16px;
        font-weight: 500;
        cursor: pointer;
        transition: all 0.2s;
    }

    .auth-button:hover {
        opacity: 0.9;
        transform: translateY(-1px);
    }

    .button-icon {
        width: 20px;
        height: 20px;
    }

    .auth-footer {
        margin-top: 32px;
        text-align: center;
        color: var(--color-text-primary);
        opacity: 0.8;
    }

    .auth-footer a {
        color: var(--color-text-primary);
        text-decoration: none;
        font-weight: 500;
    }

    .auth-footer a:hover {
        text-decoration: underline;
    }

    /* Media Queries */
    @media (max-width: 480px) {
        .auth-box {
            padding: 24px;
        }

        .auth-header {
            margin-bottom: 24px;
        }

        .auth-form {
            gap: 20px;
        }
    }
</style>
