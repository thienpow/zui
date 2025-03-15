
<style>
    main {
        background: inherit;
        width: 100%;
        margin: 0;
        padding: 0;
    }
    .htmx-indicator {
        display: none;
        text-align: center;
        padding: 10px;
        color: var(--color-text-primary);
    }
    .htmx-request .htmx-indicator {
        display: block;
    }
    .htmx-request.button {
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
    }

    .auth-box {
        width: 100%;
        max-width: 420px;
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
        z-index: 1;
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

    /* custom checkbox */
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

    @media (prefers-color-scheme: dark) {
      .checkmark {
        border-color: #666; /* Subtle border in dark mode */
      }
      .checkbox-container input:checked + .checkmark {
        background: #1e90ff; /* Blue instead of white */
        border-color: #1e90ff;
      }
    }

    .btn-submit {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        font-size: 16px;
        font-weight: 500;
        padding: 12px 24px;
        width: 100%;
        border: 1px solid rgba(169, 169, 169, 0.1);
        border-radius: var(--border-radius);
    }

    @media (max-width: 480px) {
        .btn-submit {
            padding: 8px 16px;
        }
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

/* below is all for oauth, but it should follow the theme above... maybe btn-oauth should be removed */

    .btn-google {
      background-color: white;
      color: #757575;
      border: 1px solid #ddd;
    }

    .btn-google:hover {
      background-color: #f5f5f5;
    }

    .btn-github {
      background-color: #24292e;
      color: white;
      border: 1px solid #24292e;
    }

    .btn-github:hover {
      background-color: #2f363d;
    }

    .oauth-providers {
      margin-top: 24px;
      text-align: center;
    }

    .oauth-providers h3 {
      margin-bottom: 16px;
      font-size: 14px;
      color: #666;
      position: relative;
    }

    .oauth-providers h3:before,
    .oauth-providers h3:after {
      content: "";
      position: absolute;
      top: 50%;
      width: 30%;
      height: 1px;
      background-color: #ddd;
    }

    .oauth-providers h3:before {
      left: 0;
    }

    .oauth-providers h3:after {
      right: 0;
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
