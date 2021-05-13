(module markdown-svnwiki
  (markdown->svnwiki
   pre-processing
   post-processing
   toc)

(import scheme)

(cond-expand
  (chicken-4
    (import
      chicken
      scheme
      files
      irregex
      data-structures
      srfi-1
      ports
      extras
      srfi-13)
    (use lowdown sxml-transforms miscmacros))
  (chicken-5
    (import
      (chicken base)
      (chicken io)
      (chicken irregex)
      (chicken port)
      srfi-1
      srfi-13
      lowdown
      sxml-transforms
      miscmacros)))

(define references (make-parameter #f))

(define toc (make-parameter #t))

(define pre-processing
  (make-parameter
   `((code-blocks .
      ,(lambda (s)  ; Deal with code blocks (``` lang ... ```)
         (irregex-replace/all
          '(: "\n```" (* whitespace)
              (submatch-named lang (+ alphanumeric))
              (submatch-named body (*? any)) "\n```")
          s
          (lambda (m)
            (string-append "\n    [lang:"
                           (string-downcase (irregex-match-substring m 'lang))
                           "]\n"
                           (irregex-replace/all
                            "\n" (irregex-match-substring m 'body) "\n    ")))))))))

;; Convert verbatim blocks containing [definition-type] into <definition-type tags
(define (definition name)
  (cons (string->symbol name)
        (lambda (s)
          (irregex-replace/all
           `(: "\n [" ,name "]" (* whitespace) (submatch-named def (+ (~ #\newline))) eol)
           s
           (lambda (m)
             (string-append "\n<" name ">" (irregex-match-substring m 'def)
                            "</" name ">"))))))

(define post-processing
  (make-parameter
   `((code-blocks .
      ,(lambda (s) ; Convert [lang:xxx] verbatim blocks into <enscript> tags
         (irregex-replace/all
          '(: "\n [lang:" (submatch-named lang (+ alphanumeric)) "]\n"
              (submatch-named body (+ bol " " (* (~ #\newline)) #\newline)))
          s
          (lambda (m)
            (string-append "\n<enscript highlight=\""
                           (irregex-match-substring m 'lang)
                           "\">"
                           (irregex-replace/all
                            "\n " (irregex-match-substring m 'body) "\n")
                           "</enscript>\n")))))
     ,(definition "procedure")
     ,(definition "macro")
     ,(definition "read")
     ,(definition "parameter")
     ,(definition "record")
     ,(definition "string")
     ,(definition "class")
     ,(definition "method")
     ,(definition "constant")
     ,(definition "setter")
     ,(definition "syntax")
     ,(definition "type"))))

(define (call-with-reference attrs proc)
  (if* (alist-ref (car (alist-ref 'ref attrs))
                  (references) equal?)
       (proc it attrs)
       (alist-ref 'input attrs)))

(define (ref->alist-entry ref)
  (cons (car (alist-ref 'label (cdr ref)))
        (cdr ref)))

(define (make-link ref #!optional attrs)
  `("[[" ,(alist-ref 'href ref)
    ,(if* (alist-ref 'label (or attrs ref))
          (list "|" it)
          '())
    "]]"))

(define (make-image ref #!optional attrs)
  `("[[image:" ,(alist-ref 'href ref)
    ,(if* (alist-ref 'label (or attrs ref))
          (list "|" it)
          '())
    "]]"))

(define conversion-rules
  `((heading . ,(lambda (_ attrs)
                  (list #\newline
                        (make-string (add1 (car attrs)) #\=)
                        #\space
                        (cadr attrs)
                        #\newline
                        (if (and (= (car attrs) 1) (toc))
                            '("[[toc:]]" #\newline)
                            '()))))
    (paragraph . ,(lambda (_ attrs)
                    `(,attrs #\newline #\newline)))
    (br . ,(lambda _ (#\newline #\newline)))
    (explicit-link . ,(lambda (_ attrs)
                        (make-link attrs)))
    (reference-link . ,(lambda (_ attrs)
                         (call-with-reference attrs make-link)))
    (auto-link . ,(lambda (_ attrs)
                    `("[[" ,(alist-ref 'href attrs) "]]")))
    (image . ,(lambda (_ attrs)
                (make-image attrs)))
    (reference-image . ,(lambda (_ attrs)
                          (call-with-reference attrs make-image)))
    (bullet-list . ,(lambda (_ items)
                      (list (map (lambda (s) (cons "*" s)) items) #\newline)))
    (ordered-list . ,(lambda (_ items)
                       (list (map (lambda (s) (cons "#" s)) items) #\newline)))
    (item . ,(lambda (_ contents)
               `(#\space ,@contents #\newline)))
    (verbatim . ,(lambda (_ attrs)
                   (list
		    (map (lambda (s)
			   (map (lambda (s) (list " " s)) (if (list? s) s (list s))))
			 attrs)
		    #\newline)))
    (code . ,(lambda (_ attrs)
               `("{{" ,@attrs "}}")))
    (emphasis . ,(lambda (_ text)
                   `("''" ,@text "''")))
    (strong . ,(lambda (_ text)
                 `("'''" ,@text "'''")))
    (html-element . ,(lambda (_ contents)
                       contents))
    (comment . ,(lambda (_ contents)
                  (list #\< "!--" contents "--" #\> #\newline)))
    . ,alist-conv-rules*))

(define (markdown->svnwiki input)
  (define (reference-element? el)
    (and (pair? el) (eq? 'reference (car el))))
  (define (process funs string)
    (let loop ([str string] [processing funs])
      (if (null? processing)
          str
          (loop ((cdar processing) str)
                (cdr processing)))))
  (let* ([input (if (port? input)
                    (let ((s (read-string #f input)))
                      (if (eof-object? s) "" s))
                    input)]
         [string (process (pre-processing) input)])
    (receive (refs sxml) (partition reference-element? (markdown->sxml* string))
      (parameterize ((references (map ref->alist-entry refs)))
        (write-string (process (post-processing)
                               (with-output-to-string
                                 (lambda ()
                                   (SRV:send-reply
                                    (pre-post-order* sxml conversion-rules))))))))))
) ;module end
