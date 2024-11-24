<footer>
    <div class="footer-content">
        <div class="footer-section">
            <h3>About</h3>
            <p>I am Pow, zUI is a UIKit for Jetzig.</p>
        </div>
        <div class="footer-section">
            <h3>Quick Links</h3>
            <ul>
                <li><a href="/">Home</a></li>
                <li><a href="/about">About</a></li>
                <li><a href="/admin">Services</a></li>
            </ul>
        </div>
        <div class="footer-section">
            @partial layouts/landing/contact
        </div>
    </div>
</footer>



<style>
    footer {
        background-color: #333;
        color: white;
        padding: 2rem;
        margin-top: auto;
    }

    .footer-content {
        max-width: 1200px;
        margin: 0 auto;
        display: flex;
        justify-content: space-between;
        flex-wrap: wrap;
        gap: 2rem;
    }

    .footer-section {
        flex: 1;
        min-width: 250px;
    }

    .footer-section h3 {
        margin-bottom: 1rem;
    }

    .footer-section ul {
        list-style: none;
    }

    .footer-section ul li {
        margin-bottom: 0.5rem;
    }

    .footer-section ul li a {
        color: white;
        text-decoration: none;
    }

    footer .contact {
        --color-text-primary: #ffffff;
    }

    footer .contact p {
        opacity: 0.9;
    }
</style>
