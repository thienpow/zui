<section><div class="table-section">
    <table class="table">
        <thead>
            <tr>
                <th>User</th>
                <th>Email</th>
                <th>Role</th>
                <th>Join Date</th>
                <th>Status</th>
                <th>Actions</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td class="user-cell">
                    @partial libs/icons/placeholder_rounded_32
                    <div class="user-info">
                        <span class="user-name">John Doe</span>
                        <span class="user-id">#USR123456</span>
                    </div>
                </td>
                <td>john.doe@example.com</td>
                <td>Admin</td>
                <td>Jan 15, 2024</td>
                <td><span class="status-badge active">Active</span></td>
                <td class="actions-cell">
                    <button class="action-btn edit">
                        @partial libs/icons/edit_pen_paper
                    </button>
                    <button class="action-btn delete">
                        @partial libs/icons/delete_dustbin
                    </button>
                </td>
            </tr>
        </tbody>
    </table>
    @partial libs/components/pagination
</div></section>
