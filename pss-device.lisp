(defparameter *d1* 0.1)

(defparameter *d2* 1)

(defparameter *frank-data* '((controls . (67.66 63.25))
			     (on-dopa . (78.96 57.92))
			     (off-dopa . (64.67 81.95)))
  "Data from Frank, Seeberger, and O'Reilly's 2004 study" )


(defun simulate (n &optional (params nil))
  (let ((results nil))
    (dotimes (i n)
      (let ((p (make-instance 'pss-task)))
	(suppress-warnings (reload))
	(install-device p)
	(init p)
	(proc-display)
	(sgp :v nil)
	
	;; Applies the necessary parameters
	(when params
	  (apply 'sgp params)) 
        ;; (sgp :trace-filter production-firing-only)
	(run 3000)
	
	(push (calculate-choose-avoid (experiment-log (current-device)))
	      results)))
    (mapcar 'float (list (apply 'mean (mapcar 'first results))
			 (apply 'mean (mapcar 'second results))))))
  

;;; ------------------------------------------------------------------
;;; MULTI-PARAMETER OPTIMIZATION
;;; ------------------------------------------------------------------
;;; Performs derivative-free optimization over parameter space
;;; ------------------------------------------------------------------

(defun ps-point? (pnt)
  "A PS point is a list of keyword/value conses" 
  (and (every 'consp pnt)
       (every 'keywordp (mapcar #'first pnt))))

(defun ps-point-equal? (pnt1 pnt2)
  "Two PS points are equal if they conta
in the same values"
  (and (ps-point? pnt1)
       (ps-point? pnt2)
       (= (length pnt1) (length pnt2))
       (every #'(lambda (x) (member x pnt2 :test #'equalp))
	      pnt1)))

(defun copy-ps-point (pnt)
  "Creates a deep copy of a point"
  (when (ps-point? pnt)
    (mapcar #'(lambda (x) (cons (first x) (rest x)))
	    pnt)))


(defun replace-value (point param newval)
  "Replaces the value of a parameter in a point. Returns a copy"
  (let ((newpoint (copy-ps-point point)))
    (setf (cdr (assoc param newpoint)) newval)
    newpoint))

(defun generate-sampling-points (point param step)
  "Generate sampling points across one dimension (parameter) for a given point"
  (let* ((initial (cdr (assoc param point)))
	 (vals (list (- initial step) initial (+ initial step))))
    (mapcar #'(lambda (x) (replace-value point param x))
	    vals)))

(defun determine-new-space-positions (point steps)
  "Samples across multiple parameters"
  (let ((results (list point)))
    (dolist (pair steps results)
      (let ((param (first pair))
	    (step (rest pair)))
	(setf results
	      (append results (mapcan #'(lambda (x)
					  (generate-sampling-points x param step))
				      results)))))
    (remove-duplicates results :test #'ps-point-equal?)))


(defun parameter-optimize (start steps function reference &optional (previously-sampled nil))
  ;; Calculates an objective function of the results 
  (let* ((samples (determine-new-space-positions start steps))
	 (new-points (remove-if #'(lambda (x) (member
					       x
					       previously-sampled
					       :test #'ps-point-equal?))
				samples))
	 (results (mapcar #'(lambda (point) (simulate 100 point))
			  new-points))
	 (values (mapcar function results))
	 (minimum-value (apply 'min values))
	 (minimum-value-index (position minimum-value values))
	 (min-point (nth minimum-value-index new-points)))
    
    (cond ((< minimum-value reference)
	   (parameter-optimize min-point
			       steps
			       function
			       minimum-value
			       (append previously-sampled new-points)))
	  (t
	   (cons start reference)))))
      
      
    
(defun bg-reward-hook (production reward time)
  (declare (ignore time))
  (let* ((name (symbol-name production))
	 (start (subseq name 0 4)))

    (cond ((string-equal start "PICK")
	   (* *d1* reward))
	  ((string-equal start "DONT")
	   (* *d2* reward))
	  (t
	   nil))))

(defun bg-utility-hook (production)
  (let* ((name (symbol-name production))
	 (start (subseq name 0 4)))))


(defun act-r-loaded? ()
  "Cheap hack to check whether ACTR is loaded"
  (and (fboundp 'run-n-events)
       (fboundp 'start-environment)))

;; ---------------------------------------------------------------- ;;
;; Some utilities
;; ---------------------------------------------------------------- ;;

(defun pick (lst)
  "Picks up an element from a list"
  (when  (listp lst)
    (elt lst (random (length lst)))))


(defun scramble (lst &optional (sofar nil))
  "Scrambles a list of different elements"
  (if (null lst)
      sofar
    (let ((picked (pick lst)))
      (scramble (remove picked lst) (cons picked sofar)))))

(defun scramble* (lst)
  "Scrambles any list of objects"
  (let ((l (length lst))
        (pos nil))
    (dotimes (i l)
      (push i pos))
    (mapcar #'(lambda (x) (elt lst x)) (scramble pos))))

(defun mean (&rest nums)
  (when (every #'numberp nums)
    (/ (reduce #'+ nums)
       (length nums))))

;; ---------------------------------------------------------------- ;;
;; Data structures and parameters for the task
;; ---------------------------------------------------------------- ;;

(defparameter *stimuli* '(shape-A shape-B shape-C shape-D shape-E shape-F))

(defparameter *probabilities* '((shape-A . 0.8) (shape-B . 0.2)
				(shape-C . 0.7) (shape-D . 0.3)
				(shape-E . 0.6) (shape-F . 0.4)))

(defparameter *training-pairs* '((shape-A shape-B) (shape-B shape-A)
				 (shape-C shape-D) (shape-D shape-C)
				 (shape-E shape-F) (shape-F shape-E)))

(defparameter *testing-pairs* '((shape-A shape-C) (shape-A shape-D)
				(shape-A shape-E) (shape-A shape-F)
				(shape-B shape-C) (shape-B shape-D)
				(shape-B shape-E) (shape-B shape-F)))




(defparameter *training* (scramble* (let ((results nil))
				      (dolist (pair *training-pairs* results)
					(dotimes (i 10)
					  (push (copy-seq pair) results))))))

(defparameter *testing* (scramble* (let ((results nil))
				     (dolist (pair *testing-pairs* results)
				       (dotimes (i 2)
					 (push (copy-seq pair) results)
					 (push (reverse (copy-seq pair)) results))))))


(defparameter *key-mappings* '((f . 0) (j . 1)))

(defun option? (val)
  (member val *stimuli*))

(defun choice? (lst)
  (and (= (length lst) 2)
       (every #'option? lst)))

(defun best-option (choice)
  (when (choice? choice)
    (let* ((probs (mapcar #'(lambda (x) (cdr (assoc x *probabilities*))) choice))
	   (max (apply 'max probs))
	   (pos (position max probs :test #'=)))
      (nth pos choice))))
	  


;; A trial is a list with this structure:
;;
;; ((option1 option1) chosen-option best-option feedback)) 

(defun make-trial (choice)
  (list choice nil nil nil nil))

(defun trial-options (trial)
  (first trial))

(defun trial-choice (trial)
  (first trial)) ; Same thing as -options

(defun trial-chosen-option (trial)
  (second trial))

(defun trial-feedback (trial)
  (fourth trial))

(defun trial-pphase (trial)
  (fifth trial))

(defun trial-best-option (trl)
  (best-option (trial-choice trl)))

(defun trial-accuracy (trial)
  (if (equal (trial-best-option trial)
	     (trial-chosen-option trial))
      1
      0))


(defun set-trial-chosen-option (trl option)
  (setf (nth 1 trl) option))

(defun set-trial-choice (trl option)
  (setf (nth 0 trl) option))

(defun set-trial-best-option (trl option)
  (setf (nth 2 trl) option))
  
(defun set-trial-feedback (trl feedback)
  (setf (nth 3 trl) feedback))

(defun set-trial-pphase (trl pphase)
  (setf (nth 4 trl) pphase))

(defun equal-options? (choice1 choice2)
  "Two choices have equal options if they options are the same indendent of the order"
  (and (choice? choice1)
       (choice? choice2)
       (or (equal choice1 choice2)
	   (equal choice1 (reverse choice2)))))


(defun training-passed? (lst)
  "Success criterion according to Frank"
  (let* ((lst-AB (remove-if-not #'(lambda (x)
				    (equal-options? x '(shape-A shape-B))) lst
				    :key 'trial-options))
	 (lst-CD (remove-if-not #'(lambda (x)
				    (equal-options? x '(shape-C shape-D))) lst
				    :key 'trial-options))
	 (lst-eF (remove-if-not #'(lambda (x)
				    (equal-options? x '(shape-E shape-F))) lst
				    :key 'trial-options))
	 (acc-ab (apply 'mean (mapcar #'trial-accuracy lst-ab)))
	 (acc-cd (apply 'mean (mapcar #'trial-accuracy lst-cd)))
	 (acc-ef (apply 'mean (mapcar #'trial-accuracy lst-ef))))
    (and (> acc-ab 0.65)
	 (> acc-cd 0.55)
	 (> acc-ef 0.50))))
	

;; ---------------------------------------------------------------- ;;
;; The task device
;; ---------------------------------------------------------------- ;;
	     
(defclass pss-task ()
  ((pphase :accessor pphase
	  :initform nil)
   (index :accessor index
	  :initform nil)
   (training-trials :accessor training-trials
		    :initform *training*)
   (test-triasl :accessor test-trials
		:initform *testing*)
   (current-trial :accessor current-trial
		  :initform nil)
   (experiment-log :accessor experiment-log
		   :initform nil))
  (:documentation "A manager for the PSS task"))

(defmethod init ((task pss-task))
  "Initializes the PSS task manager"
  (when (and (not (null (test-trials task)))
	     (not (null (training-trials task))))
    (setf (index task) 0)
    (setf (experiment-log task) nil)
    (setf (test-trials task) (scramble* (test-trials task)))
    (setf (training-trials task) (scramble* (training-trials task)))
    (setf (current-trial task) (make-trial (nth (index task) (training-trials task))))
    (setf (pphase task) 'training))
    (set-trial-pphase (current-trial task) 'training))

(defmethod respond ((task pss-task) key)
  "Records a response in the PSS task"
  (unless (null (current-trial task))
    (let* ((trial (current-trial task))
	   (choice (trial-choice trial))
	   (chosen (nth (cdr (assoc key *key-mappings*))
			choice))
	   (n (random 1.0))
	   (prob (cdr (assoc chosen *probabilities*)))
	   
	   (feedback (< n prob)))

      (set-trial-chosen-option trial chosen)
      (set-trial-best-option trial (trial-best-option trial))
      (set-trial-feedback trial feedback))

    ;; If ACT-R is loaded, we need to sync the visicon with the
    ;; state of the task.

    (when (act-r-loaded?)
      (cond ((equal (pphase task) 'test)
	     (schedule-event-relative 0 #'next :params (list task)))
	    ((equal (pphase task) 'training)
	     (schedule-event-relative 0 #'proc-display :params nil)
	     (schedule-event-relative 3 #'next :params (list task)))
	    (t
	     (schedule-event-relative 0 #'proc-display :params nil))))))
      


(defmethod next ((task pss-task))
  "Moves on to the next stage of the task"
  (unless (null (index task))  ; If it null, the tast is not initialized yetr
    (incf (index task))  ; Increament the index. This is easy
    (push (current-trial task) (experiment-log task))
    (cond ((equal (pphase task) 'training) ; We are in training pphase
	   (cond ((< (index task) (length (training-trials task)))
		  (setf (current-trial task)
			(make-trial (nth (index task)
					 (training-trials task))))
		  (set-trial-pphase (current-trial task) (pphase task)))
		 (t
		  (cond ((or (training-passed? (subseq (experiment-log task) 0 60))
			     (>= (length (experiment-log task)) 360))
			 (print '(Pass to training))
			 (setf (pphase task)
			       'test)
			 (setf (index task)
			       0)
			 (setf (current-trial task)
			       (make-trial (nth 0 (test-trials task))))
			 (set-trial-pphase (current-trial task) (pphase task)))
			(t ; if trainijng not passed
			 (setf (index task)
			       0)
			 (setf (training-trials task)
			       (scramble* (training-trials task)))
			 (setf (current-trial task)
			       (make-trial (nth 0 (training-trials task))))
			 (set-trial-pphase (current-trial task) (pphase task)))))))
	  
	  ((equal (pphase task) 'test)
	   (cond ((< (index task) (length (test-trials task)))
		  (setf (current-trial task)
			(make-trial (nth (index task) (test-trials task))))
		  (set-trial-pphase (current-trial task) (pphase task)))
		 (t
		  (setf (pphase task) 'done)))))
    (when (act-r-loaded?)
      (proc-display :clear t))))


(defun process-reward ()
  "Transforms the task manager's feedback into numeric reward and has ACT-R process it"
  (let* ((feedback (trial-feedback (current-trial (current-device))))
	 (reward (if feedback 1 -1)))
    (trigger-reward reward)))
    
	    
;; ---------------------------------------------------------------- ;;
;; ACT-R Device Interface
;; ---------------------------------------------------------------- ;;

(defmethod build-vis-locs-for ((device pss-task) vismod)
  "Creates a list of visual locations"
  (let* ((pphase (pphase device))
	 (trial (current-trial device))
	 (feedback (trial-feedback trial))
	 (choice (trial-choice trial)))
    (cond ((and (or (equal pphase 'test)
		    (and (equal pphase 'training)
			 (null (trial-chosen-option trial)))))
	   (funcall #'define-chunks-fct 
		    (list `(isa visual-location 
				kind option
				value ,(first choice)
				color black
				position left
				screen-x 100 
				screen-y 100 
				height 200 
				width 100)
			  `(isa visual-location 
				kind option
				value ,(second choice)
				color black
				position right
				screen-x 400 
				screen-y 100 
				height 200 
				width 100)
			  `(isa visual-location 
				kind screen
				value choices
				color black
				position center
				screen-x 200 
				screen-y 150 
				height 100 
				width 200))))
    
	  ((And (equal pphase 'training)
		(not (null (trial-chosen-option trial))))
	   (funcall #'define-chunks-fct 
		    (list `(isa visual-location 
				kind feedback
				value ,(if feedback 'correct 'incorrect)
				color ,(if feedback 'blue 'red)
				shape text
				position center
				screen-x 200 
				screen-y 150
				height 100 
				width 200))))
	  
	  ((and (equal pphase 'done))
	   (funcall #'define-chunks-fct 
		    (list `(isa visual-location 
				kind done
				value done
				color black
				shape text
				position center
				screen-x 200 
				screen-y 150 
				height 200 
				width 100)))))))
	
(defmethod device-handle-keypress ((tm pss-task) key)
  "Converts the key into a symbol and passes it on to the task manager"
  (let ((val (read-from-string (format nil "~a" key))))
    (respond tm val)))
			   
(defmethod device-handle-click ((device pss-task))
  "Does nothing"
  (declare (ignore device))
  nil)

(defmethod device-move-cursor-to ((device pss-task) pos)
  "Does nothing"
  (declare (ignore device))
  nil)


(defmethod get-mouse-coordinates ((device pss-task))
  "Does nothing"
  (declare (ignore device))
  (vector 0 0))

(defmethod cursor-to-vis-loc ((device pss-task))
  "Does nothing"
  (declare (ignore device))
  nil)


(defmethod vis-loc-to-obj ((device pss-task) vis-loc)
  "Transforms a visual-loc into a visual object"
  (let ((kind (chunk-slot-value-fct vis-loc 'kind))
	(value (chunk-slot-value-fct vis-loc 'value))
	(position (chunk-slot-value-fct vis-loc 'position))
	(new-chunk nil))
    (setf new-chunk (first (define-chunks-fct 
			       `((isa visual-object 
				      value ,value
				      what ,kind
				      shape ,value
				      position ,position
				  )))))
    (fill-default-vis-obj-slots new-chunk vis-loc)
    new-chunk))


(defun schedule-task-update (tm)
  "Schedules the next update of the trial manager"
  (when (act-r-loaded?)
    (proc-display)
    (update-window tm)
    (unless (member (state tm) *wait-states*)
      (let ((duration 0))
	(cond ((member (state tm) *blanks*)
	       (setf duration (+ 2 (* 2 (random 3)))))
	      ((member (state tm) *fixations*)
	       (setf duration 2))
	      ((equal (state tm) 'probe)
	       (setf duration 2))
	      ((equal (state tm) 'feedback)
	       (setf duration 2)))
	(schedule-event-relative duration #'next :params (list tm))))))

(defun calculate-choose-avoid (log)
  (let* ((data (remove-if-not #'(lambda (x) (equal x 'test)) log :key 'trial-pphase))
	 (a-list (remove-if-not #'(lambda (x) (member 'shape-a (trial-choice x))) data))
	 (b-list (remove-if-not #'(lambda (x) (member 'shape-b (trial-choice x))) data))
	 (a-list (remove-if #'(lambda (x) (member 'shape-b (trial-choice x))) a-list))
	 (b-list (remove-if #'(lambda (x) (member 'shape-a (trial-choice x))) b-list))
	 (choose-a (apply 'mean (mapcar 'trial-accuracy a-list)))
	 (avoid-b (apply 'mean (mapcar 'trial-accuracy b-list))))
    (print (list (length a-list) (length b-list)))
    (list choose-a avoid-b)))

(defun pss-reload ()
  (reload)
  (install-device p)
  (init p)
  (proc-display))

