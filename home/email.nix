{ pkgs, ... }: {
  home.file.".mbsyncrc".text = ''
    # ACCOUNT INFORMATION
    IMAPAccount gmail
    Host imap.gmail.com
    User lnajt4@gmail.com
    PassCmd "pass show email/lnajt4@gmail.com-emacsapppassword"
    AuthMechs LOGIN
    SSLType IMAPS
    # SSLVersions TLSv1.3
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
    Far :gmail-remote:
    Near :gmail-local:
    Patterns "INBOX"
    Create Both
    Expunge Both
    SyncState *
    SyncState *
    MaxMessages 1000
    MaxSize 200k
    ExpireUnread yes

    Channel gmail-trash
    Far :gmail-remote:"[Gmail]/Bin"
    Near :gmail-local:"[Gmail].Bin"
    Create Both
    Expunge Both
    SyncState *
    MaxMessages 100
    MaxSize 200k
    ExpireUnread yes

    Channel gmail-sent
    Far :gmail-remote:"[Gmail]/Sent Mail"
    Near :gmail-local:"[Gmail].Sent Mail"
    Create Both
    Expunge Both
    SyncState *
    MaxMessages 1000
    MaxSize 200k
    ExpireUnread yes


    Channel gmail-drafts
    Far :gmail-remote:"[Gmail]/Drafts"
    Near :gmail-local:"[Gmail].Drafts"
    Create Both
    Expunge Both
    SyncState *
    MaxMessages 100
    MaxSize 200k
    ExpireUnread yes


    Channel gmail-all
    Far :gmail-remote:"[Gmail]/All Mail"
    Near :gmail-local:"[Gmail].All Mail"
    Create Both
    Expunge Both
    SyncState *
    MaxMessages 1000
    MaxSize 200k
    ExpireUnread yes

    Channel gmail-starred
    Far :gmail-remote:"[Gmail]/Starred"
    Near :gmail-local:"[Gmail].Starred"
    Create Both
    Expunge Both
    SyncState *
    MaxMessages 1000
    MaxSize 200k
    ExpireUnread yes

    Group gmail
    Channel gmail-inbox
    Channel gmail-sent
    Channel gmail-trash
    Channel gmail-all
    Channel gmail-starred
    Channel gmail-drafts

  '';

  # Ensure mail directories exist
  home.activation.createMailDirs = ''
    mkdir -p ~/Maildir/{INBOX,queue/cur,[Gmail].{Bin,All Mail,Sent Mail,Starred}}
  '';
}
