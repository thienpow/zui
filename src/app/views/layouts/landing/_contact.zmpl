<div class="contact">
    <h3>Let's Connect</h3>
    <p>Feel free to reach out through any of these channels:</p>
    <ul>
        <li>✉️ Email: <a href="mailto:thienpow@gmail.com">thienpow@gmail.com</a></li>
        <li>
            <svg class="x-icon" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24">
                <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/>
            </svg>
            <a href="https://x.com/thienpow" target="_blank">@thienpow</a>
        </li>
        <li>
            <svg class="github-icon" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24">
                <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/>
            </svg>
            <a href="https://github.com/thienpow" target="_blank">thienpow</a>
        </li>
    </ul>
</div>


<style>
    .contact {
        color: var(--color-text-primary, #2d333b);
    }

    .contact h3 {
        margin-bottom: 1rem;
    }

    .contact p {
        margin-bottom: 1rem;
    }

    .contact a {
        display: inline-flex;
        align-items: center;
        color: inherit;
        text-decoration: none;
        padding: 4px 8px;
        border-radius: 4px;
        transition: all 0.3s ease;
        position: relative;
    }

    .contact a:hover {
        color: #0366d6;
        background-color: rgba(3, 102, 214, 0.1);
        transform: translateY(-1px);
    }

    .contact a::after {
        content: "";
        position: absolute;
        width: 0;
        height: 2px;
        bottom: 0;
        left: 50%;
        background-color: currentColor;
        transition: all 0.3s ease;
    }

    .contact a:hover::after {
        width: 80%;
        left: 10%;
    }

    .contact .x-icon,
    .contact .github-icon {
        vertical-align: middle;
        margin-right: 5px;
        fill: currentColor;
        transition: transform 0.3s ease;
    }

    .contact a:hover .x-icon,
    .contact a:hover .github-icon {
        transform: scale(1.1);
    }

    .contact li {
        display: flex;
        align-items: center;
        gap: 5px;
        margin: 12px 0;
    }
</style>
