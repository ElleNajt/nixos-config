{ pkgs, ... }: {
  home.file.".mbsyncrc".text = ''
    # ACCOUNT INFORMATION
    IMAPAccount gmail
    Host imap.gmail.com
    User lnajt4@gmail.com
    PassCmd "pass show email/lnajt4@gmail.com-emacsapppassword"
    AuthMechs LOGIN
    SSLType IMAPS
    SSLVersions TLSv1.3
    CertificateFile ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

    # REMOTE STORAGE
    IMAPStore gmail-remote
    Account gmail

    # LOCAL STORAGE
    MaildirStore gmail-local
    Path ~/Maildir/
    Inbox ~/Maildir/INBOX

    # CHANNELS
    Channel gmail-inbox
    Master :gmail-remote:
    Slave :gmail-local:
    Patterns "INBOX"
    Create Both
    Expunge Both
    SyncState *
    SyncState *
    MaxMessages 1000
    MaxSize 200k

    Channel gmail-trash
    Master :gmail-remote:"[Gmail]/Bin"
    Slave :gmail-local:"[Gmail].Bin"
    Create Both
    Expunge Both
    SyncState *
    MaxMessages 100
    MaxSize 200k

    Channel gmail-sent
    Master :gmail-remote:"[Gmail]/Sent Mail"
    Slave :gmail-local:"[Gmail].Sent Mail"
    Create Both
    Expunge Both
    SyncState *
    MaxMessages 1000
    MaxSize 200k

    Channel gmail-all
    Master :gmail-remote:"[Gmail]/All Mail"
    Slave :gmail-local:"[Gmail].All Mail"
    Create Both
    Expunge Both
    SyncState *
    MaxMessages 1000
    MaxSize 200k

    Channel gmail-starred
    Master :gmail-remote:"[Gmail]/Starred"
    Slave :gmail-local:"[Gmail].Starred"
    Create Both
    Expunge Both
    SyncState *
    MaxMessages 1000
    MaxSize 200k

    Group gmail
    Channel gmail-inbox
    Channel gmail-sent
    Channel gmail-trash
    Channel gmail-all
    Channel gmail-starred
  '';

  # Ensure mail directories exist
  home.activation.createMailDirs = ''
    mkdir -p ~/Maildir/{INBOX,queue/cur,[Gmail].{Bin,All Mail,Sent Mail,Starred}}
  '';
}
