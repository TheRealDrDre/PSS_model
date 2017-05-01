(load "/projects/actr/actr7/load-act-r.lisp")
(load "../pss-device.lisp")
(load "../pss-addition.lisp")
(load "../pss-simulations.lisp")
(setf *d1* 1 *d2* 1)
(with-open-file (out "sims-alpha.txt" :direction :output 
		     :if-exists :overwrite :if-does-not-exist :create)
  (simulate-alpha-egs "../pss-model-new-equation.lisp"
		      250
		      (seq 0.001 0.1 0.001)
		      :egs-vals '(0.1)
		      :stream out
		      :report nil
		      :utilities t
		      )) 
(quit)
