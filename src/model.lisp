(in-package :simple-game)

(defclass model ()
  ((floor-tiles :type array
                :initform (make-array (list +world-size+ +world-size+) :initial-element nil)
                :reader get-floor-tiles)
   (dungeon :type hash-region
            :initform (make-hash-region)
            :initarg :dungeon
            :reader get-dungeon)
   (game-objects :type game-object-hash-storage
                 :initform (make-game-object-storage)
                 :accessor get-game-objects)
   (game-objects-by-positon :type hash-table
                            :initform (make-hash-table :test 'object-equal-p)
                            :accessor get-game-objects-by-position)
   (events :type event-hash-storage
           :initform (make-event-hash-storage)
           :reader events)))

(defmethod get-object-at ((position vector2) (model model))
  (gethash position (get-game-objects-by-position model)))

(defmethod tile-at-p ((position vector2) (model model))
  (handler-case (aref (get-floor-tiles model) (get-x position) (get-y position))
    (sb-int:invalid-array-index-error (e) (declare (ignore e)) nil)))

  ;; (handler-bind ((sb-int:invalid-array-index-error #'(lambda (_) (declare (ignore _)) nil)))
  ;;   (aref (get-floor-tiles model) (get-x position) (get-y position)))

(defmethod get-player ((model model))
  (first (set-to-list (get-game-objects-of-class (find-class 'player) (get-game-objects model)))))

(defun clear-game-objects (model)
  (setf (get-game-objects model) (make-game-object-storage)))

(defclass game-object-hash-storage ()
  ((game-objects :type hash-table
                 :initform (make-hash-table)
                 :reader get-game-objects
                 :documentation "map of superclass name to set of game object")))

(defun make-game-object-storage ()
  (make-instance 'game-object-hash-storage))

(defmethod add-game-object (game-object (objects game-object-hash-storage))
  (dolist (superclass (get-superclasses game-object))
    (setf (gethash (class-name superclass) (get-game-objects objects))
          (set-add game-object (gethash (class-name superclass) (get-game-objects objects))))))

(defmethod add-game-object (game-object (model model))
  (add-game-object game-object (get-game-objects model)))
;; Adding game object to model involves updating position hash
(defmethod add-game-object :after ((game-object has-position) (model model))
  (setf (gethash (pos game-object) (get-game-objects-by-position model)) game-object))

(defmethod remove-game-object (game-object (objects game-object-hash-storage))
  (dolist (superclass (get-superclasses game-object))
    (setf (gethash (class-name superclass) (get-game-objects objects))
          (set-remove game-object (gethash (class-name superclass) (get-game-objects objects))))))

(defmethod remove-game-object (game-object (model model))
  (remove-game-object game-object (get-game-objects model)))
;; Removing game object to model involves updating position hash
(defmethod remove-game-object :after ((game-object has-position) (model model))
  (remhash (pos game-object) (get-game-objects-by-position model)))

(defmethod get-game-objects-of-class (class (objects game-object-hash-storage))
  (gethash (class-name class) (get-game-objects objects)))

(defclass event-hash-storage ()
  ((priority-to-events :type hash-table
                       :initform (make-hash-table)
                       :reader by-priority)))

(defun make-event-hash-storage ()
  (make-instance 'event-hash-storage))

(defmethod get-events-of-priority (priority (events event-hash-storage))
  (gethash priority (by-priority events)))

(defmethod add-event (event (events event-hash-storage))
  (push event (gethash (get-priority event) (by-priority events))))

(defmethod purge-events ((events event-hash-storage))
  (setf (slot-value events 'priority-to-events) (make-hash-table)))

;;(deftype event-queue () hash-table)

;; (defclass layout-builder
;;     ())

(defun model-init ()
  (let ((dungeon (assemble-dungeon 10 70)))
    (defparameter *model* (make-instance 'model :dungeon dungeon))
    (carve-region dungeon *model*)
    (spawn (make-instance 'player) *model*)
    (defparameter *player* (get-player *model*))
    (dotimes (_ 4)
      (spawn (make-instance 'confused-snake) *model*))))

;; (spawn (make-instance 'confused-shade) *model*)

(defun spawn (has-position model)
  (setf (pos has-position) (random-element (get-locations (get-dungeon model))))
  (unless (get-object-at (pos has-position) model)
    (add-game-object has-position (get-game-objects model))))

(defun between (x y)
  (if (< x y)
      (iter (for i from x to y)
        (collect i))
      (iter (for i from y to x)
        (collect i))))

;; Carve regions in model
(defun carve-location (location model)
    (let ((x (get-x location))
          (y (get-y location))) 
      (setf (aref (get-floor-tiles model) x y) t)))
(defun carve-region (region model)
  (iter (for location in (get-locations region))
    (carve-location location model)))
