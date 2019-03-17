(module markdown-svnwiki-command ()

(import scheme)

(cond-expand
  (chicken-4
    (import chicken scheme irregex)
    (use files markdown-svnwiki srfi-37))
  (chicken-5
    (import
      (chicken base)
      (chicken irregex)
      (chicken pathname)
      (chicken process-context)
      markdown-svnwiki
      srfi-37)))

(define (help option name arg seed)
  (print
"usage: markdown-svnwiki [-h | --help]
                        [-o | --output-file NAME]
                        [-e | --extension EXTENSION]
                        [-t | --no-toc]
                        [file]

Convert the given Markdown file to CHICKEN's svnwiki syntax. 
If no file is given, stdin is read. If neither the output-file 
or extension arguments are given, the result is written to stdout. 
If the output-file argument is provided, the resulting svnwiki 
file is written to a file of that name. If the extension argument 
is given, the svnwiki file uses the same name as the input file, 
with the given extension.")
  (exit 0))

(define (usage option name arg seed)
  (print "unrecognized option: " name)
  (help option name arg seed))

(define file-extension (make-parameter #f))

(define (output-file option name arg seed)
  (current-output-port (open-output-file arg))
  seed)

(define (extension option name arg seed)
  (file-extension arg)
  seed)

(define (no-toc option name arg seed)
  (toc #f)
  seed)

(define options
  (list (option '(#\h "help")        #f #f help)
        (option '(#\o "output-file") #t #f output-file)
        (option '(#\t "no-toc")      #f #f no-toc)
        (option '(#\e "extension")   #t #f extension)))

(define (convert name seed)
  (unless seed
    (when (file-extension)
      (current-output-port
       (open-output-file (pathname-replace-extension name (file-extension)))))
    (current-input-port (open-input-file name))
    (markdown->svnwiki (current-input-port)))
  #t)

(args-fold (cdr (argv)) options usage convert #f)
(markdown->svnwiki (current-input-port))

) ;end module
