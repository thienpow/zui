<div class="sidebar-overlay" onclick="closeSidebar()"></div>
<div id="sidebar" class="sidebar">
    @partial libs/components/brand_sidebar
    <ul class="sidebar-menu">
        <li>
            <a hx-get="/admin/dashboard"
               hx-push-url="true"
               hx-target="main"
               hx-swap="innerHTML" >
                @partial libs/icons/dashboard
                Dashboard
            </a>
        </li>

        <li>
            <a hx-get="/admin/products"
               hx-push-url="true"
               hx-target="main"
               hx-swap="innerHTML" >
                @partial libs/icons/products
                Products
            </a>
        </li>
        <li>
            <a hx-get="/admin/orders"
               hx-push-url="true"
               hx-target="main"
               hx-swap="innerHTML" >
                @partial libs/icons/orders
                Orders
            </a>
        </li>
        <li>
            <a hx-get="/admin/users"
               hx-push-url="true"
               hx-target="main"
               hx-swap="innerHTML" >
                @partial libs/icons/users
                Users
            </a>
        </li>
        <li>
            <a hx-get="/admin/settings"
               hx-push-url="true"
               hx-target="main"
               hx-swap="innerHTML" >
                @partial libs/icons/settings
                Settings
            </a>
        </li>
    </ul>

    <div class="sidebar-footer">
        <div class="profit-section">
            <div class="profit-label">Total Profit</div>
            <div class="profit-amount">$128,459</div>
            <a href="/admin/profits" class="profit-btn">View Details →</a>
        </div>
    </div>
</div>
<button class="hamburger-btn" onclick="toggleSidebar()">
    <span></span>
    <span></span>
</button>


<style>
    .sidebar {
        display: flex;
        flex-direction: column;
        position: fixed;
        left: 0;
        top: 0;
        height: 100vh;
        width: 250px;
        background: #2c3e50;
        padding: 30px 20px;
        color: var(--color-text-primary);
        z-index: 1000;
        transition: transform 0.3s ease;
        background: var(--color-bg);
    }

    .sidebar-overlay {
        display: none;
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background-color: rgba(0, 0, 0, 0.7);
        backdrop-filter: blur(4px);
        -webkit-backdrop-filter: blur(4px);
        z-index: 999;
        opacity: 0;
        transition: opacity 0.3s ease;
    }

    .menu-icon {
        width: 20px;
        height: 20px;
        stroke: currentColor;
        opacity: 0.8;
    }

    .sidebar-menu {
        flex: 1;
        list-style: none;
        margin-bottom: 20px;
    }

    .sidebar-menu li {
        padding: 8px 0;
        border-bottom: none;
        transition: all 0.2s ease;
    }

    .sidebar-menu li a {
        color: var(--color-text-primary);
        text-decoration: none;
        padding: 8px 15px;
        border-radius: 8px;
        transition: all 0.2s ease;
        display: flex;
        align-items: center;
        gap: 12px;
    }

    .sidebar-menu li a:hover {
        cursor: pointer;
        background: rgba(0,0,0,0.05);
        transform: translateX(5px);
    }

    .sidebar-menu li:last-child {
        border-bottom: none; /* Removes border from last item */
    }

    .sidebar-footer {
        margin-top: auto;
        padding: 20px 15px;
        border-top: 1px solid rgba(0,0,0,0.1);
        position: relative;
        bottom: 0;
        width: 100%;
        left: 0;
    }

    .profit-section {
        text-align: center;
        padding: 0 15px;
    }

    .profit-label {
        font-size: 14px;
        color: var(--color-text-primary);
        opacity: 0.7;
        margin-bottom: 5px;
    }

    .profit-amount {
        font-size: 36px;
        font-weight: bold;
        color: var(--color-text-primary);
        margin-bottom: 15px;
        font-family: 'Georgia', serif;
    }

    .profit-btn {
        display: inline-block;
        padding: 8px 20px;
        background: var(--color-surface);
        color: var(--color-text-primary);
        text-decoration: none;
        border-radius: 6px;
        font-size: 14px;
        transition: all 0.2s ease;
        border: 1px solid rgba(0,0,0,0.1);
    }

    .profit-btn:hover {
        background: rgba(0,0,0,0.05);
        transform: translateY(-2px);
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
        top: 20px;
        left: 20px;
        transition: left 0.3s cubic-bezier(0.4, 0.0, 0.2, 1);
    }

    .hamburger-btn span {
        display: block;
        width: 17px;
        height: 1px;
        background-color: var(--color-text-primary);
        position: absolute;
        left: 6px;
        transition: all 0.3s cubic-bezier(0.4, 0.0, 0.2, 1);
    }

    .hamburger-btn.active span {
        background-color: var(--color-text-primary);
    }

    .hamburger-btn:not(.active) span {
        background-color: var(--color-text-primary);
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

    /* Media query for small screens */
    @media (max-width: 768px) {
        .sidebar {
            transform: translateX(-100%);
        }

        .sidebar.active {
            transform: translateX(0);
        }

        .hamburger-btn {
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .hamburger-btn.active {
            left: 260px; /* sidebar width (250px) + some spacing */
        }

        .hamburger-btn.active span {
            background-color: white;
        }
        .hamburger-btn:not(.active) span {
            background-color: #2c3e50;
        }

        .sidebar-overlay.active {
            display: block;
            opacity: 1;
            top: 0;
        }
    }
</style>

<script>
    function toggleSidebar() {
        const menuBtn = document.querySelector('.hamburger-btn');
        const sidebar = document.getElementById('sidebar');
        const overlay = document.querySelector('.sidebar-overlay');

        menuBtn.classList.toggle('active');
        sidebar.classList.toggle('active');
        overlay.classList.toggle('active');

        // Prevent body scrolling when sidebar is open
        document.body.style.overflow = sidebar.classList.contains('active') ? 'hidden' : '';
    }

    function closeSidebar() {
        const menuBtn = document.querySelector('.hamburger-btn');
        const sidebar = document.getElementById('sidebar');
        const overlay = document.querySelector('.sidebar-overlay');

        menuBtn.classList.remove('active');
        sidebar.classList.remove('active');
        overlay.classList.remove('active');
        document.body.style.overflow = '';
    }

    // Close sidebar when clicking on a link
    document.querySelectorAll('.sidebar-menu a').forEach(link => {
        link.addEventListener('click', closeSidebar);
    });
</script>
