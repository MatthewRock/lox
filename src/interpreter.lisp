(in-package :clox)

;; Since this is CL version and not Java,
;; we have to define different bijection between the types
;; We will treat Lox's nil the same as the CL's nil because
;; Lox's nil does imply false, same as  CL's.
;; Lox type - CL type
;; nil - null (equivalent to nil)
;; boolean - Boolean (T + NIL)
;; number - Number
;; string - String

(defgeneric evaluate (expression)
  (:documentation "Evaluate THING."))

(defgeneric is-truthy (thing)
  (:documentation "Return T if the THING is truthy, NIL otherwise."))

(defgeneric add (operator left right)
  (:documentation "Add LEFT and RIGHT, operation depending on the type. OPERATOR is passed to provide meaningful error in case of type error."))

(defmethod add (operator left right)
  (error 'clox-runtime-error :token operator
                             :message (format nil
                                              "Both operands have to be either number or string.~%Left=~S ; Right = ~S"
                                              left right)))

(defmethod add (operator (left string) (right string))
  (concatenate 'string left right))

(defmethod add (operator (left number) (right number))
  (+ left right))

(defmethod add (operator (left string) (right number))
  (add left (stringify right)))

(defmethod add (operator (left number) (right string))
  (add (stringify left) right))

(defgeneric check-number-operand (operator right)
  (:documentation "Signal runtime error if right is not a number."))

(defmethod check-number-operand (operator right)
  (error 'clox-runtime-error :token operator
                             :message (format nil "Right operand is not a number : ~S" right)))

(defmethod check-number-operand (operator (right number))
  t)

(defgeneric check-number-operands (operator left right)
  (:documentation "Signal runtime error if any of the operands is not a number."))

(defmethod check-number-operands (operator (left number) (right number))
  t)

(defmethod check-number-operands (operator (left number) right)
  (error 'clox-runtime-error :token operator
                             :message (format nil "Left operand is not a number.~%Left=~S" left)))

(defmethod check-number-operands (operator left (right number))
  (error 'clox-runtime-error :token operator
                             :message (format nil "Right operand is not a number.~%Right=~S" right) ))

(defmethod check-number-operands (operator left right)
  (error 'clox-runtime-error :token operator
                             :message (format nil
                                              "Left and right operand are not a number.~%Left = ~S ; Right = ~S"
                                              left right)))

;; TODO: Ask on the IRC: Why do I have to define it BEFORE the method?

(defmacro typed-binary-expression-case (operator left right &body clauses)
  "Call proper function provided by CLAUSES depending on the OPERATOR (its token). Clauses look like (TOKEN-NAME FUNCTION-NAME). The names of the LEFT and RIGHT are passed as arguments.

Types:
operator - Token
left - Symbol
right - Symbol
clauses - list (keyword symbol)"
  `(case (token-type ,operator)
     ,@(loop for (token-name function-name) in clauses
             collecting `(,token-name
                          (check-number-operands ,operator ,left ,right)
                          (,function-name ,left, right)))))

;; Purely cosmetic for now
;; Will hold environment in the future
(defclass interpreter () ())

;; NULL, NIL and false all evaluate to NIL and are the only false values for Lox.
(defmethod is-truthy ((thing (eql nil)))
  nil)
;; Everything else is truthy.
(defmethod is-truthy (thing)
  t)

(defmethod evaluate ((expression literal-expr))
  (value expression))

(defmethod evaluate ((expression unary-expr))
  (let* ((right (evaluate (right expression)))
         (operator (operator expression))
         (operator-type (token-type operator)))
    (case operator-type
      (:minus
       (check-number-operand operator right)
       (- right))
      (:bang (not (is-truthy right))))))

(defmethod evaluate ((expression binary-expr))
  (let* ((left (evaluate (left expression)))
         (right (evaluate (right expression)))
         (operator (operator expression))
         (operator-type (token-type operator)))
    (handler-case
        (or
         (typed-binary-expression-case operator left right
           (:minus -)
           (:slash /)
           (:star *)
           (:greater >)
           (:greater-equal >=)
           (:less <)
           (:less-equal <=))
         (ecase operator-type
           (:plus (add operator left right))
           (:bang-equal (not-equal left right))
           (:equal-equal (equal left right))
           (:comma right)))
      (division-by-zero () (error 'clox-runtime-error :token operator :message "Division by zero.")))))

(defmethod evaluate ((expression ternary-expr))
  (ecase (token-type (operator expression))
    (:question-mark (if (evaluate (question expression))
                        (evaluate (result-true expression))
                        (evaluate (result-false expression))))))

(defgeneric stringify (thing)
  (:documentation "Convert THING to printable form (does not have to be string)"))

(defmethod stringify (thing)
  thing)

(defmethod stringify ((thing ratio))
  (coerce thing 'double-float))

(defmethod stringify ((thing double-float))
  (multiple-value-bind (num reminder) (floor thing)
    (if (zerop reminder)
        num
        thing)))

(-> interpret (expr) t)
(defun interpret (expression)
  (format nil "~A" (stringify (evaluate expression))))
