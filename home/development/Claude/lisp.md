# Lisp

Parens -- use the emacs mcp server to fix unbalanced parens issues

Common pattern for fixing parentheses: when check-parens goes to the beginning of a function, find the next defun and add )) before it.

Use emacsclient to reload files and functions. IMPORTANT -- if you have edited a elisp file and are debugging it, make sure to reload the file using mcpclient.