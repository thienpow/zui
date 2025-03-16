<img src="/icons/logo.svg" class="logo-mobile" alt="zUI Logo">
<button class="hamburger-btn" onclick="toggleMenu()">
    <span></span>
    <span></span>
</button>
<div id="mobile-nav" class="mobile-nav">
    <div style="height: 90px;"></div>
    @partial layouts/landing/menu_items
</div>


<style>
.logo-mobile {
    visibility: hidden;
    position: fixed;
    top: 12px;
    left: 0px;
    width: 100px;
    height: 48px;
    z-index: 1002;
}
.hamburger-btn {
    display: none;
    background: none;
    border: none;
    cursor: pointer;
    padding: 10px;
    z-index: 1002;
    width: 30px;
    height: 30px;
    position: fixed;
    top: 12px;
    right: 20px;
}

.hamburger-btn span {
    display: block;
    width: 17px;
    height: 1px;
    background-color: white;
    position: absolute;
    left: 6px;
    transition: all 0.3s cubic-bezier(0.4, 0.0, 0.2, 1);
}

.hamburger-btn span:nth-child(1) {
    top: 12px;
}

.hamburger-btn span:nth-child(2) {
    top: 18px;
}

.hamburger-btn.active span:nth-child(1) {
    transform: rotate(45deg);
    top: 15px;
}

.hamburger-btn.active span:nth-child(2) {
    transform: rotate(-45deg);
    top: 15px;
}

.mobile-nav {
    display: none;
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 54px;
    background-color: rgba(26, 26, 26, 0.95);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    overflow: hidden;
    transition: height 0.4s cubic-bezier(0.4, 0.0, 0.2, 1);
    z-index: 1001;
}

.mobile-nav.active {
    height: 100vh;
    display: flex;
    flex-direction: column;
    overflow-y: auto;
}

.mobile-nav a {
    display: block;
    color: white;
    text-decoration: none;
    padding: 8px 48px;
    font-size: 24px;
    font-weight: 400;
    letter-spacing: -0.5px;
    opacity: 0;
    transform: translateY(20px);
    transition: all 0.3s ease;
    cursor: pointer;
    position: relative;
    overflow: hidden;
}

.mobile-nav.active a {
    opacity: 1;
    transform: translateY(0);
}

/* Cascade animation delays */
.mobile-nav a:nth-child(1) { transition-delay: 0.1s; }
.mobile-nav a:nth-child(2) { transition-delay: 0.15s; }
.mobile-nav a:nth-child(3) { transition-delay: 0.2s; }
.mobile-nav a:nth-child(4) { transition-delay: 0.25s; }

.mobile-nav a:hover {
    color: #ffffff;
    background-color: rgba(255, 255, 255, 0.1);
    text-shadow: 0 0 8px rgba(255, 255, 255, 0.5);
}

/* Active/Click effect */
.mobile-nav a:active {
    background-color: rgba(255, 255, 255, 0.2);
    transform: scale(0.98);
    transition: all 0.1s ease;
}

/* Ripple effect on click */
.mobile-nav a:after {
    content: '';
    position: absolute;
    width: 100%;
    height: 100%;
    top: 0;
    left: 0;
    pointer-events: none;
    background-image: radial-gradient(circle, #ffffff 10%, transparent 10.01%);
    background-repeat: no-repeat;
    background-position: 50%;
    transform: scale(10, 10);
    opacity: 0;
    transition: transform 0.5s, opacity 0.5s;
}

.mobile-nav a:active:after {
    transform: scale(0, 0);
    opacity: 0.3;
    transition: 0s;
}

/* Media Queries */
@media (max-width: 768px) {
    .logo-mobile {
        visibility: visible;
    }
    .hamburger-btn {
        display: flex;
        align-items: center;
        justify-content: center;
    }
    .mobile-nav {
        display: block;
    }
}

@media (max-width: 480px) {
    .mobile-nav a {
        padding: 8px 24px; /* Reduced vertical padding for mobile */
        font-size: 21px;
    }
}
</style>

<script>
    function toggleMenu() {
        const menuBtn = document.querySelector('.hamburger-btn');
        const mobileNav = document.getElementById('mobile-nav');

        menuBtn.classList.toggle('active');
        mobileNav.classList.toggle('active');

        // Prevent body scrolling when menu is open
        document.body.style.overflow = mobileNav.classList.contains('active') ? 'hidden' : '';
    }

    // Close mobile menu when clicking on a link
    document.querySelectorAll('.mobile-nav a').forEach(link => {
        link.addEventListener('click', () => {
            const menuBtn = document.querySelector('.hamburger-btn');
            const mobileNav = document.getElementById('mobile-nav');

            menuBtn.classList.remove('active');
            mobileNav.classList.remove('active');
            document.body.style.overflow = '';
        });
    });
</script>
