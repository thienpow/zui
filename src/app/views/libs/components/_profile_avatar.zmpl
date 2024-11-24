<div class="avatar-section">
    <img src="/icons/placeholder_avatar.svg" class="profile-avatar" />
    <div class="avatar-overlay">
        <label for="avatar-upload" class="avatar-upload-btn">
            @partial libs/icons/upload
            Change Photo
        </label>
        <input type="file" id="avatar-upload" hidden accept="image/*">
    </div>
</div>


<style>
    .avatar-section {
        position: relative;
    }

    .profile-avatar {
        width: 120px;
        height: 120px;
        border-radius: 50%;
        object-fit: cover;
    }

    .avatar-overlay {
        position: absolute;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        border-radius: 50%;
        background: rgba(0,0,0,0.5);
        display: flex;
        align-items: center;
        justify-content: center;
        opacity: 0;
        transition: opacity 0.2s ease;
    }

    .avatar-section:hover .avatar-overlay {
        opacity: 1;
    }

    .avatar-upload-btn {
        color: white;
        cursor: pointer;
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 5px;
        font-size: 14px;
    }

    .upload-icon {
        width: 24px;
        height: 24px;
    }
</style>


<script>
    // Handle avatar upload
    document.getElementById('avatar-upload').addEventListener('change', function(e) {
        if (e.target.files && e.target.files[0]) {
            const reader = new FileReader();
            reader.onload = function(e) {
                document.querySelector('.profile-avatar').src = e.target.result;
            }
            reader.readAsDataURL(e.target.files[0]);
        }
    });
</script>
