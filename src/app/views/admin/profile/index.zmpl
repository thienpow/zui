<div class="main-content">
    <div class="content-header">
        <h1>Profile</h1>
    </div>

    <div class="profile-container">
        <!-- Profile Header -->
        <div class="profile-header">
            @partial libs/components/profile_avatar
            <div class="profile-info">
                <h2>John Doe</h2>
                <span class="role-badge">Administrator</span>
            </div>
        </div>

        <!-- Profile Sections -->
        <div class="profile-sections">
            <!-- Personal Information -->
            <div class="profile-section">
                <h3>Personal Information</h3>
                <div class="form-group">
                    <label>Full Name</label>
                    <input type="text" value="John Doe" class="form-input">
                </div>
                <div class="form-group">
                    <label>Email Address</label>
                    <input type="email" value="john@example.com" class="form-input">
                </div>
                <div class="form-group">
                    <label>Phone Number</label>
                    <input type="tel" value="+1 234 567 8900" class="form-input">
                </div>
                <button>Save Changes</button>
            </div>

            <!-- Security -->
            <div class="profile-section">
                <h3>Security</h3>
                <div class="form-group">
                    <label>Current Password</label>
                    <input type="password" class="form-input">
                </div>
                <div class="form-group">
                    <label>New Password</label>
                    <input type="password" class="form-input">
                </div>
                <div class="form-group">
                    <label>Confirm New Password</label>
                    <input type="password" class="form-input">
                </div>
                <button>Update Password</button>
            </div>

            <!-- Roles and Permissions -->
            <div class="profile-section">
                <h3>Roles and Permissions</h3>
                <div class="roles-list">
                    <div class="role-item">
                        <span class="role-name">Administrator</span>
                        <span class="role-description">Full access to all features</span>
                    </div>
                    <div class="permissions-grid">
                        <div class="permission-item">
                            <span class="permission-name">User Management</span>
                            <span class="permission-status granted">✓</span>
                        </div>
                        <div class="permission-item">
                            <span class="permission-name">Content Management</span>
                            <span class="permission-status granted">✓</span>
                        </div>
                        <div class="permission-item">
                            <span class="permission-name">System Settings</span>
                            <span class="permission-status granted">✓</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<style>
    button {
        padding: 12px 24px;
        white-space: nowrap;
    }

    .profile-container {
        max-width: 800px;
        margin: 0 auto;
    }

    .profile-header {
        display: flex;
        align-items: center;
        gap: 30px;
        margin-bottom: 40px;
        padding: 30px;
        background: var(--color-surface);
        border-radius: 15px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.05);
    }

    .profile-info h2 {
        margin: 0;
        color: var(--color-text-primary);
        font-size: 24px;
    }

    .role-badge {
        display: inline-block;
        padding: 5px 12px;
        background: rgba(44, 62, 80, 0.1);
        color: var(--color-text-primary);
        border-radius: 15px;
        font-size: 14px;
        margin-top: 8px;
    }

    .profile-sections {
        display: grid;
        gap: 24px;
    }

    .profile-section {
        background: var(--color-surface);
        padding: 30px;
        border-radius: 15px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.05);
    }

    .profile-section h3 {
        margin: 0 0 20px 0;
        color: var(--color-text-primary);
        font-size: 18px;
    }

    .form-group {
        margin-bottom: 20px;
    }

    .form-group label {
        display: block;
        margin-bottom: 8px;
        color: var(--color-text-primary);
        font-size: 14px;
        opacity: 0.8;
    }

    .form-input {
        width: 100%;
        padding: 10px 15px;
        font-size: 15px;
    }

    .roles-list {
        background: rgba(0,0,0,0.02);
        padding: 20px;
        border-radius: 8px;
    }

    .role-item {
        margin-bottom: 15px;
    }

    .role-name {
        display: block;
        font-weight: 600;
        color: var(--color-text-primary);
    }

    .role-description {
        font-size: 14px;
        opacity: 0.7;
    }

    .permissions-grid {
        display: grid;
        gap: 10px;
        margin-top: 15px;
        max-width: 380px;
    }

    .permission-item {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 10px 15px;
        border-radius: 6px;
    }

    .permission-status.granted {
        color: #27ae60;
        font-weight: bold;
    }

    @media (max-width: 768px) {
        .profile-header {
            flex-direction: column;
            text-align: center;
            padding: 20px;
        }

        .profile-section {
            padding: 20px;
        }
    }
</style>
