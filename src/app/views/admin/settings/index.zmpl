<div class="main-content">
    <div class="content-header">
        <div class="header-main">
            <h1>Settings</h1>
            <div class="header-stats">
                <div class="stat-card">
                    <div class="stat-info">
                        <span class="stat-label">System Version</span>
                        <span class="stat-value">v2.4.1</span>
                    </div>
                    @partial libs/icons/settings_gear
                </div>

                <div class="stat-card">
                    <div class="stat-info">
                        <span class="stat-label">Last Updated</span>
                        <span class="stat-value">2 days ago</span>
                    </div>
                    @partial libs/icons/settings_last_updated
                </div>
            </div>
        </div>
    </div>

    <div class="settings-container">
        <!-- Appearance Settings -->
        <section>
            <h2 class="section-title">
                @partial libs/icons/settings_appearance
                Appearance
            </h2>
            <div class="settings-content">
                <div class="setting-item">
                    <div class="setting-label">
                        <span>Theme</span>
                        <span class="setting-description">Choose your preferred color theme</span>
                    </div>
                    <div class="theme-selector">
                        <button class="theme-btn active" style="--theme-color: #2c3e50;">
                            <span class="theme-check">✓</span>
                        </button>
                        <button class="theme-btn" style="--theme-color: #3498db;"></button>
                        <button class="theme-btn" style="--theme-color: #2ecc71;"></button>
                        <button class="theme-btn" style="--theme-color: #e74c3c;"></button>
                        <button class="theme-btn" style="--theme-color: #f1c40f;"></button>
                        <button class="theme-btn" style="--theme-color: #9b59b6;"></button>
                    </div>
                </div>

                <div class="setting-item">
                    <div class="setting-label">
                        <span>Dark Mode</span>
                        <span class="setting-description">Switch between light and dark mode</span>
                    </div>

                    <label id="toggle-switch" class="toggle-switch">
                        <input type="checkbox" {{$.dark}} name="dark"
                            hx-post="/admin/settings/toggle_dark"
                            hx-target="#toggle-switch"
                            hx-swap="innerHTML"
                            hx-include="this">
                        <span class="toggle-slider"></span>
                    </label>
                </div>

                <div class="setting-item">
                    <div class="setting-label">
                        <span>Reduced Motion</span>
                        <span class="setting-description">Minimize animation effects</span>
                    </div>
                    <label class="toggle-switch">
                        <input type="checkbox">
                        <span class="toggle-slider"></span>
                    </label>
                </div>
            </div>
        </section>

        <!-- Localization Settings -->
        <section>
            <h2 class="section-title">
                @partial libs/icons/settings_localization
                Localization
            </h2>
            <div class="settings-content">
                <div class="setting-item">
                    <div class="setting-label">
                        <span>Language</span>
                        <span class="setting-description">Select your preferred language</span>
                    </div>
                    <select class="setting-select">
                        <option value="en">English</option>
                        <option value="es">Español</option>
                        <option value="fr">Français</option>
                        <option value="de">Deutsch</option>
                        <option value="zh">中文</option>
                    </select>
                </div>

                <div class="setting-item">
                    <div class="setting-label">
                        <span>Region</span>
                        <span class="setting-description">Set your location for regional settings</span>
                    </div>
                    <select class="setting-select">
                        <option value="us">United States</option>
                        <option value="uk">United Kingdom</option>
                        <option value="eu">European Union</option>
                        <option value="ca">Canada</option>
                        <option value="au">Australia</option>
                    </select>
                </div>

                <div class="setting-item">
                    <div class="setting-label">
                        <span>Currency</span>
                        <span class="setting-description">Choose your preferred currency</span>
                    </div>
                    <select class="setting-select">
                        <option value="usd">USD ($)</option>
                        <option value="eur">EUR (€)</option>
                        <option value="gbp">GBP (£)</option>
                        <option value="jpy">JPY (¥)</option>
                        <option value="aud">AUD ($)</option>
                    </select>
                </div>
            </div>
        </section>

        <!-- Notification Settings -->
        <section>
            <h2 class="section-title">
                @partial libs/icons/settings_notifications
                Notifications
            </h2>
            <div class="settings-content">
                <div class="setting-item">
                    <div class="setting-label">
                        <span>Email Notifications</span>
                        <span class="setting-description">Receive updates via email</span>
                    </div>
                    <label class="toggle-switch">
                        <input type="checkbox" checked>
                        <span class="toggle-slider"></span>
                    </label>
                </div>

                <div class="setting-item">
                    <div class="setting-label">
                        <span>Push Notifications</span>
                        <span class="setting-description">Receive browser notifications</span>
                    </div>
                    <label class="toggle-switch">
                        <input type="checkbox">
                        <span class="toggle-slider"></span>
                    </label>
                </div>
            </div>
        </section>
    </div>
</div>

@partial libs/styles/content_header

<style>
    .settings-container {
        display: flex;
        flex-direction: column;
        gap: 32px;
        max-width: 1200px; /* Max width for large screens */
        margin: 0 auto; /* Center on the page */
        width: 100%; /* Ensure it takes up full width on smaller screens */
    }

    .section-title {
        display: flex;
        align-items: center;
        gap: 12px;
        margin: 0;
        padding: 20px 24px;
        border-bottom: 1px solid rgba(169, 169, 169, 0.1);
        font-size: 18px;
        font-weight: 600;
        color: var(--color-text-primary);
    }

    .section-icon {
        width: 24px;
        height: 24px;
        color: var(--color-text-primary);
    }

    .settings-content {
        padding: 24px;
    }

    .setting-item {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 16px 0;
        border-bottom: 1px solid rgba(169, 169, 169, 0.1);
    }

    .setting-item:last-child {
        border-bottom: none;
        padding-bottom: 0;
    }

    .setting-label {
        display: flex;
        flex-direction: column;
        gap: 4px;
    }

    .setting-label span:first-child {
        font-weight: 500;
        color: var(--color-text-primary);
    }

    .setting-description {
        font-size: 14px;
        color: var(--color-text-primary);
        opacity: 0.6;
    }

    .setting-select {
        padding: 8px 12px;
        border: 1px solid rgba(169, 169, 169, 0.1);
        border-radius: 6px;
        min-width: 200px;
        font-size: 14px;
    }

    /* Theme Selector */
    .theme-selector {
        display: flex;
        gap: 12px;
    }

    .theme-btn {
        width: 36px;
        height: 36px;
        border-radius: 50%;
        border: 2px solid transparent;
        background-color: var(--theme-color);
        cursor: pointer;
        position: relative;
        transition: all 0.2s ease;
    }

    .theme-btn.active {
        border-color: var(--color-text-primary);
    }

    .theme-check {
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        color: white;
        font-size: 16px;
    }

    /* Toggle Switch */
    .toggle-switch {
        position: relative;
        display: inline-block;
        width: 50px;
        height: 24px;
    }

    .toggle-switch input {
        opacity: 0;
        width: 0;
        height: 0;
    }

    .toggle-slider {
        position: absolute;
        cursor: pointer;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background-color: var(--color-inactive);
        transition: .4s;
        border-radius: 34px;
    }

    .toggle-slider:before {
        position: absolute;
        content: "";
        height: 20px;
        width: 20px;
        left: 2px;
        bottom: 2px;
        background-color: var(--color-surface);
        transition: .4s;
        border-radius: 50%;
    }

    .toggle-switch input:checked + .toggle-slider {
        background-color: var(--color-accent);
    }

    .toggle-switch input:checked + .toggle-slider:before {
        transform: translateX(26px);
    }

    /* Media Queries */
    @media (max-width: 768px) {
        .settings-container {
            padding: 0px 12px;
            gap: 16px;
        }

        .setting-item {
            flex-direction: column;
            align-items: flex-start;
            gap: 12px;
        }

        .setting-select {
            width: 100%;
        }

        .theme-selector {
            margin-top: 8px;
        }
    }

    @media (max-width: 480px) {
        .settings-container {
            padding: 16px 6px;
            gap: 8px;
        }
    }
</style>

<script>
document.body.addEventListener('htmx:afterRequest', (event) => {
    const { xhr } = event.detail;
    if (event.target && event.target.id === "toggle-switch") {
        if (xhr.status === 201) {
          location.href = "/admin/settings";
        }
    }
});
</script>
