<div class="top-user-info" onclick="toggleUserDropdown(event)">
    <span class="user-name">John Doe</span>

    @partial libs/icons/placeholder_rounded_40

    <!-- Dropdown Menu -->
    <div class="user-dropdown">
        <div class="dropdown-header">
            @partial libs/icons/placeholder_rounded_40
            <div class="user-details">
                <span class="user-fullname">John Doe</span>
                <span class="user-email">john@example.com</span>
            </div>
        </div>
        <div class="dropdown-divider"></div>
        <a hx-get="/admin/profile"
            hx-push-url="true"
            hx-target="main"
            hx-swap="innerHTML"
            class="dropdown-item"
            onclick="handleProfileClick(event)">
            <svg class="dropdown-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
            </svg>
            My Profile
        </a>
        <a href="/auth/logout" class="dropdown-item logout-item">
            <svg class="dropdown-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/>
            </svg>
            Logout
        </a>
    </div>
</div>

<style>
    .top-user-info {
        display: flex;
        align-items: center;
        gap: 12px;
        position: relative;
        padding: 5px;
        border-radius: 25px;
        cursor: pointer;
        transition: all 0.2s ease;
    }

    .top-user-info:hover {
        background: rgba(0,0,0,0.05);
    }

    .user-name {
        color: var(--color-text-primary);
        font-weight: 500;
    }

    .top-user-info img {
        width: 40px;
        height: 40px;
        border-radius: 50%;
        object-fit: cover;
        border: 2px solid transparent;
        transition: border-color 0.2s ease;
    }

    .top-user-info:hover img {
        border-color: rgba(0,0,0,0.1);
    }

    /* Dropdown Styles */
    .user-dropdown {
        position: absolute;
        top: calc(100% + 10px);
        right: 0;
        width: 280px;
        background: var(--color-surface, white);
        border-radius: 12px;
        box-shadow: 0 4px 20px rgba(0,0,0,0.15);
        opacity: 0;
        visibility: hidden;
        transform: translateY(-10px);
        transition: all 0.2s ease;
        z-index: 1000;
    }

    .user-dropdown.active {
        opacity: 1;
        visibility: visible;
        transform: translateY(0);
    }

    .dropdown-header {
        padding: 20px;
        display: flex;
        align-items: center;
        gap: 15px;
    }

    .dropdown-header img {
        width: 50px;
        height: 50px;
    }

    .user-details {
        display: flex;
        flex-direction: column;
    }

    .user-fullname {
        font-weight: 600;
        color: var(--color-text-primary);
    }

    .user-email {
        font-size: 14px;
        color: var(--color-text-primary);
        opacity: 0.7;
    }

    .dropdown-divider {
        height: 1px;
        background: rgba(0,0,0,0.1);
        margin: 5px 0;
    }

    .dropdown-item {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 12px 20px;
        color: var(--color-text-primary);
        text-decoration: none;
        transition: background 0.2s ease;
    }

    .dropdown-item:hover {
        background: rgba(0,0,0,0.03);
    }

    .dropdown-icon {
        width: 18px;
        height: 18px;
        opacity: 0.7;
    }

    .logout-item {
        color: #e74c3c;
    }

    .logout-item .dropdown-icon {
        color: #e74c3c;
    }

    /* Media query for small screens */
    @media (max-width: 768px) {
        .top-user-info {
            display: none;
        }
    }
</style>

<script>

    function handleProfileClick(event) {
        // Close the dropdown
        const dropdown = document.querySelector('.user-dropdown');
        dropdown.classList.remove('active');
    }

    function toggleUserDropdown(event) {
        event.stopPropagation(); // Prevent event bubbling
        const dropdown = document.querySelector('.user-dropdown');
        dropdown.classList.toggle('active');
    }

    // Close dropdown when clicking outside
    document.addEventListener('click', function(event) {
        const dropdown = document.querySelector('.user-dropdown');
        if (dropdown.classList.contains('active')) {
            dropdown.classList.remove('active');
        }
    });

    // Prevent dropdown from closing when clicking inside it
    document.querySelector('.user-dropdown').addEventListener('click', function(event) {
        event.stopPropagation();
    });
</script>
