<!DOCTYPE html>
<html lang="en">
<head>
<title>zUI Security</title>
@partial layouts/meta
@partial layouts/htmx

@zig {
    if (zmpl.getT(.string, "dark")) |dark|{
        if (std.mem.eql(u8, dark, "checked")) {
            @partial libs/styles/themes/default_dark
        } else {
            @partial libs/styles/themes/default
        }
    }
}
@partial libs/styles/themes/core
@partial libs/styles/auth
</head>
<body>
    <main>{{zmpl.content}}</main>


    <script>
        const errorMessageContainer = document.querySelector('#error-message');
        const authForm = document.querySelector('.auth-form');

        const handleResponseError = (event) => {
            const { xhr } = event.detail;

            switch (xhr.status) {
                case 400:
                    errorMessageContainer.innerHTML = "Password does not match, weak, or bad.";
                    break;
                case 401:
                    errorMessageContainer.innerHTML = "Invalid data submited. Please try again.";
                    break;
                case 403:
                    errorMessageContainer.innerHTML = "Your account has been locked due to multiple failed attempts. Please contact support.";
                    break;
                case 404:
                    errorMessageContainer.innerHTML = "Account not found. Please check your email or register for a new account.";
                    break;
                case 409:
                    errorMessageContainer.innerHTML = "User already existed.  Please try again.";
                    break;
                case 429:
                    errorMessageContainer.innerHTML = "Too many login attempts. Please try again later.";
                    break;
                case 400:
                    errorMessageContainer.innerHTML = "Invalid input. Please check your email and password format.";
                    break;
                case 422:
                    errorMessageContainer.innerHTML = "Please provide valid email and password.";
                    break;
                case 500:
                default:
                    errorMessageContainer.innerHTML = "An unexpected error occurred. Please try again later or contact support.";
                    break;
            }
        };

        const handleAfterRequest = (event) => {
            const { xhr } = event.detail;

            if (xhr.status === 201) {
                errorMessageContainer.innerHTML = "Success.";

                if (xhr.responseText.trim() === "login success") {
                    window.location.href = "/admin/dashboard";

                } else if (xhr.responseText.trim() === "register success") {
                    const userEmail = document.querySelector('#email').value;
                    const url = `/auth/register/sent_confirm?email=${encodeURIComponent(userEmail)}`;
                    htmx.ajax('GET', url, {
                        target: '#auth-container',
                        swap: 'outerHTML'
                    }).then(() => {
                        console.log('Navigated to sent_confirm with email:', userEmail);
                    });

                } else if (xhr.responseText.trim() === "forgot password request success") {
                    const userEmail = document.querySelector('#email').value;
                    const url = `/auth/forgot_password/sent_confirm?email=${encodeURIComponent(userEmail)}`;
                    htmx.ajax('GET', url, {
                        target: '#auth-container',
                        swap: 'outerHTML'
                    }).then(() => {
                        console.log('Navigated to sent_confirm with email:', userEmail);
                    });

                } else if (xhr.responseText.trim() === "reset password success") {
                    const url = `/auth/reset_password/reset_confirm`;
                    htmx.ajax('GET', url, {
                        target: '#auth-container',
                        swap: 'outerHTML'
                    }).then(() => {
                        console.log('Navigated to reset_confirm:');
                    });

                } else if (xhr.responseText.trim() === "logout success") {
                    window.location.href = "/";
                }
            }
        };

        const handleSubmit = (event) => {
            errorMessageContainer.innerHTML = "";
        };

        document.body.addEventListener('htmx:responseError', handleResponseError);
        document.body.addEventListener('htmx:afterRequest', handleAfterRequest);
        authForm.addEventListener('submit', handleSubmit);

    </script>

</body>
</html>
