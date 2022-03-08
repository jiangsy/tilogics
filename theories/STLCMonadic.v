Require Import List.
Import ListNotations.
Require Import String.

Inductive ty : Type :=
  | ty_bool : ty
  | ty_func : ty -> ty -> ty.

Inductive expr : Type :=
  (* values *)
  | v_true  : expr
  | v_false : expr
  (* compound expressions *)
  | e_if    : expr -> expr -> expr -> expr
  | e_var   : string -> expr
  | e_absu  : string -> expr -> expr
  | e_abst  : string -> ty -> expr -> expr
  | e_app   : expr -> expr -> expr.

Definition env := list (string * ty).

Fixpoint value {X: Type} (var : string) (ctx : list (string * X)) : option X :=
  match ctx with
  | nil => None
  | (var', val) :: ctx' =>
      if (string_dec var var') then Some val else (value var ctx')
  end.

Reserved Notation "G |-- E ; T ~> EE"
            (at level 50).

Inductive tpb : env -> expr -> ty -> expr -> Prop :=
  | tpb_false : forall g,
      g |-- v_false ; ty_bool ~> v_false
  | tpb_true : forall g,
      g |-- v_true ; ty_bool ~> v_true
  | tpb_if : forall g cnd cnd' coq coq' alt alt' t,
      g |-- cnd ; ty_bool ~> cnd' ->
      g |-- coq ; t       ~> coq' ->
      g |-- alt ; t       ~> alt' ->
      g |-- (e_if cnd coq alt) ; t ~> (e_if cnd' coq' alt')
  | tpb_var : forall g v vt,
      value v g = Some vt ->
      g |-- (e_var v) ; vt ~> (e_var v)
  | tpb_absu : forall v vt g e e' t, (* don't we have to come up with vt ? *)
      ((v, vt) :: g) |-- e ; t ~> e' ->
                   g |-- (e_absu v e) ; (ty_func vt t) ~> (e_abst v vt e')
  | tpb_abst : forall v vt g e e' t,
      ((v, vt) :: g) |-- e ; t ~> e' ->
                   g |-- (e_abst v vt e) ; (ty_func vt t) ~> (e_abst v vt e')
  | tpb_app : forall g e1 t1 e1' e2 t2 e2',
      g |-- e1 ; (ty_func t2 t1) ~> e1' ->
      g |-- e2 ; t2 ~> e2' ->
      g |-- (e_app e1 e2) ; t1 ~> (e_app e1' e2')

  where "G |-- E ; T ~> EE" := (tpb G E T EE).

Example ex_typing1 :
  nil |-- (e_abst "x" ty_bool (e_var "x")) ; (ty_func ty_bool ty_bool) ~> (e_abst "x" ty_bool (e_var "x")).
Proof.
  apply tpb_abst. apply tpb_var. cbn. reflexivity.
Qed.

Example ex_typing2 :
  nil |-- (e_absu "x" (e_var "x")) ; (ty_func ty_bool ty_bool) ~> (e_abst "x" ty_bool (e_var "x")).
Proof.
  apply tpb_absu. apply tpb_var. cbn. reflexivity.
Qed.

Fixpoint gensem (ctx : list (string * ty)) (expression : expr) (type : ty) : Prop :=
  match expression with
  | v_true  => type = ty_bool
  | v_false => type = ty_bool
  | e_if cnd coq alt =>
      gensem ctx cnd ty_bool /\
      gensem ctx coq type    /\
      gensem ctx alt type
  | e_var var =>
      match (value var ctx) with
      | None => False
      | Some t => t = type
      end
  | e_app e1 e2 =>
      exists t2,
      gensem ctx e1 (ty_func t2 type) /\
      gensem ctx e2 t2
  | e_absu var e =>
      exists t_e t_var,
      gensem ((var, t_var) :: ctx) e t_e /\
      type = (ty_func t_var t_e)
  | e_abst var t_var e =>
      exists t_e,
      gensem ((var, t_var) :: ctx) e t_e /\
      type = (ty_func t_var t_e)
  end.

Lemma ex_gensem1 :
  gensem nil (e_app (e_absu "x" (e_var "x")) v_false) ty_bool.
Proof.
  compute. repeat eexists.
Qed.

Example ex_gensem2 :
gensem nil (e_app (e_absu "x" (v_true)) (e_absu "x" (e_var "x"))) ty_bool.
Proof.
  compute. repeat eexists.
  Unshelve. apply ty_bool.
Qed.

Inductive freeM (A : Type) : Type :=
  | ret_free : A -> freeM A
  | fail_free : freeM A
  | bind_assert_free : ty -> ty -> freeM A -> freeM A
  | bind_exists_free : (ty -> freeM A) -> freeM A.

(* PROOF MODE EXAMPLE *)

(*
Fixpoint freeM_bind [T1 T2 : Type] (m : freeM T1) (f : T1 -> freeM T2) {struct m} : freeM T2.
refine (
  match m with
  | ret_free _ a => f a
  | fail_free _ => fail_free T2
  | bind_assert_free _ t1 t2 k =>
      bind_assert_free _ t1 t2 (freeM_bind _ _ k f)
  | bind_exists_free _ tf => _
      (* bind_exists_free _ (fun t => freeM_bind (tf t) f) *)
  end). apply bind_exists_free. intros t. eapply freeM_bind. apply (tf t). apply f.
Show Proof. *)

Fixpoint freeM_bind [T1 T2 : Type] (m : freeM T1) (f : T1 -> freeM T2) : freeM T2 :=
   match m with
   | ret_free _ a => f a
   | fail_free _ => fail_free T2
   | bind_assert_free _ t1 t2 k =>
       bind_assert_free T2 t1 t2 (freeM_bind k f)
   | bind_exists_free _ tf =>
       bind_exists_free T2 (fun t : ty => freeM_bind (tf t) f)
   end.

(*
Inductive freeM (A : Type) : Type :=
  | ret_free : A -> freeM A
  | fail_free : freeM A
  | bind_assert_free : ty -> ty -> freeM A -> freeM A
  | bind_exists_free : freeM A -> freeM A.

Fixpoint freeM_bind [T1 T2 : Type] (m : freeM T1) (f : T1 -> freeM T2) : freeM T2 :=
  match m with
  | ret_free _ a => f a
  | fail_free _ => fail_free T2
  | bind_assert_free _ t1 t2 k =>
      bind_assert_free _ t1 t2 (freeM_bind k f)
  | bind_exists_free _ k =>
      bind_exists_free _ (freeM_bind k f)
  end.

 *)

Definition assert (t1 t2 : ty) := bind_assert_free _ t1 t2 (ret_free _ tt).
Check assert.
Definition magic : freeM ty := bind_exists_free _ (fun t => ret_free _ t).
Check magic.
Definition ret [A : Type] (a : A) := ret_free A a.
Definition fail {A : Type} := fail_free A.

Notation "x <- ma ;; mb" :=
        (freeM_bind ma (fun x => mb))
          (at level 80, ma at next level, mb at level 200, right associativity).
Notation "ma ;; mb" := (freeM_bind ma (fun _ => mb)) (at level 80, right associativity).
Notation "' x <- ma ;; mb" :=
        (freeM_bind ma (fun x => mb))
          (at level 80, x pattern, ma at next level, mb at level 200, right associativity,
           format "' x  <-  ma  ;;  mb").


Fixpoint infer (ctx : env) (expression : expr) : freeM (prod ty expr) :=
  match expression with
  | v_false => ret (ty_bool, expression)
  | v_true  => ret (ty_bool, expression)
  | e_if cnd coq alt =>
      '(t_cnd, e_cnd) <- infer ctx cnd ;;
      '(t_coq, e_coq) <- infer ctx coq ;;
      '(t_alt, e_alt) <- infer ctx alt ;;
      (assert t_cnd ty_bool) ;;
      (assert t_coq t_alt)   ;;
      ret (t_coq, e_if e_cnd e_coq e_alt)
  | e_var var =>
      match (value var ctx) with
      | Some t_var => ret (t_var, expression)
      | None => fail
      end
  | e_app e1 e2 =>
      '(t_e1, e_e1) <- infer ctx e1 ;;
      '(t_e2, e_e2) <- infer ctx e2 ;;
      t_magic <- magic ;;
      (assert t_e1 (ty_func t_e2 t_magic)) ;;
      ret (t_magic, e_app e_e1 e_e2)
  | e_absu var e =>
      t_var <- magic ;;
      '(t_e, e_e) <- infer ((var, t_var) :: ctx) e ;;
      ret (ty_func t_var t_e, e_abst var t_var e_e)
  | e_abst var t_var e =>
      '(t_e, e_e) <- infer ((var, t_var) :: ctx) e ;;
      ret (ty_func t_var t_e, e_abst var t_var e_e)
  end.


Compute (infer nil (e_app (e_abst "x" ty_bool (e_var "x")) v_true)).
Compute (infer nil (e_app (e_absu "x" (e_var "x")) v_true)).

Fixpoint wlp_freeM [A : Type] (m : freeM A) (Q: A -> Prop) :=
  match m with
  | ret_free _ a => Q a
  | bind_assert_free _ t1 t2 k => t1 = t2 ->
      wlp_freeM k Q
  | fail_free _ => True
  | bind_exists_free _ tf => exists t : ty, wlp_freeM (tf t) Q
  end.

Fixpoint wp_freeM [A : Type] (m : freeM A) (Q: A -> Prop) :=
  match m with
  | ret_free _ a => Q a
  | bind_assert_free _ t1 t2 k => t1 = t2 /\
      wp_freeM k Q
  | fail_free _ => False
  | bind_exists_free _ tf => forall t : ty, wp_freeM (tf t) Q
  end.

Lemma wlp_ty_eqb : forall (t1 t2 : ty) (Q : unit -> Prop),
  wlp_freeM (assert t1 t2) Q <-> (t1 = t2 -> Q tt).
Proof.
  destruct t1, t2; cbn; intuition discriminate.
Qed.

Lemma wlp_exists_type : forall (Q: ty -> Prop),
  wlp_freeM (magic) Q <-> (exists t : ty, Q t).
Proof.
  intuition.
Qed.

Lemma wlp_bind : forall {A B : Type} (m1 : freeM A) (m2 : A -> freeM B) (Q : B -> Prop),
  wlp_freeM (freeM_bind m1 m2) Q <-> wlp_freeM m1 (fun o => wlp_freeM (m2 o) Q).
Proof.
  split; induction m1; cbn; intuition; destruct H0; exists x; intuition.
Qed.

Lemma wlp_ret : forall {A : Type} (a : A) (Q : A -> Prop),
  wlp_freeM (ret a) Q <-> Q a.
Proof.
  intuition.
Qed.

Lemma wlp_fail : forall {A : Type} (Q : A -> Prop),
  wlp_freeM (fail) Q <-> True.
Proof.
  intuition.
Qed.

Lemma wlp_monotone : forall {O : Set} (P Q : O -> Prop) (m : freeM O),
  (forall o : O, P o -> Q o) -> wlp_freeM m P -> wlp_freeM m Q.
Proof.
  intros. induction m; cbn; auto. inversion H0. exists x. intuition.
Qed.

Lemma wp_ty_eqb : forall (t1 t2 : ty) (Q : unit -> Prop),
  wp_freeM (assert t1 t2) Q <-> t1 = t2 /\ Q tt.
Proof.
    split; intros.
    - inversion H. cbn in H1. auto.
    - cbn. apply H.
Qed.

Lemma wp_exists_type : forall (Q: ty -> Prop),
  wp_freeM (magic) Q <-> (forall t : ty, Q t).
Proof.
  intuition.
Qed.

Lemma wp_bind : forall {A B : Type} (m1 : freeM A) (m2 : A -> freeM B) (Q : B -> Prop),
  wp_freeM (freeM_bind m1 m2) Q <-> wp_freeM m1 (fun o => wp_freeM (m2 o) Q).
Proof.
    split; induction m1; cbn; intuition.
Qed.

Lemma wp_ret : forall {A : Type} (a : A) (Q : A -> Prop),
  wp_freeM (ret a) Q <-> Q a.
Proof.
  intuition.
Qed.

Lemma wp_fail : forall {A : Type} (Q : A -> Prop),
  wp_freeM (fail) Q <-> False.
Proof.
  cbn. intuition.
Qed.

Lemma wp_monotone : forall {O : Set} (P Q : O -> Prop) (m : freeM O),
  (forall o : O, P o -> Q o) -> wp_freeM m P -> wp_freeM m Q.
Proof.
    intros. induction m; cbn; auto.
    inversion H0. intuition.
Qed.


Lemma infer_sound : forall (G : env) (e : expr),
 wlp_freeM (infer G e) (fun '(t,ee) => G |-- e ; t ~> ee).
Proof.
  intros. generalize dependent G. induction e; cbn [infer]; intro;
  repeat (rewrite ?wlp_exists_type, ?wlp_bind, ?wlp_ty_eqb, ?wlp_ret, ?wlp_fail; try destruct o;
      try match goal with
      | IHe : forall G, wlp_freeM (infer G ?e) _ |- wlp_freeM (infer ?g ?e) _ =>
          specialize (IHe g); revert IHe; apply wlp_monotone; intros
      | |- tpb _ _ _ _ =>
          constructor
      | |- ?x = ?y -> _ =>
          intro; subst
      | |- wlp_freeM (match ?t with _ => _ end) _ =>
          destruct t eqn:?
      | |- exists t, _ =>
          exists ty_bool
      | H : ?g |-- ?e ; ?t ~> ?ee |- ?g' |-- e_app ?e1 ?e2 ; ?t' ~> e_app ?e1' ?e2' =>
              apply (tpb_app _ _ _ _ _ t0 _)
      end; try reflexivity; try assumption).
(* verbose proof for remaining existential cases ...
      - exists ty_bool. (* this honestly seems like cheating ??? *) apply wlp_bind. specialize (IHe ((s, ty_bool) :: G)). revert IHe. apply wlp_monotone. intros.
        destruct o. apply wlp_ret. constructor. apply H.
      - exists ty_bool. apply wlp_bind. apply wlp_ty_eqb. intro. apply wlp_ret. apply (tpb_app _ _ _ _ _ t0 _).
        + subst. apply H.
        + apply H0.
*)
Qed.

Lemma infer_complete : forall  (G : env) (e ee : expr) (t : ty),
  (G |-- e ; t ~> ee) -> wp_freeM (infer G e) (fun '(t',ee')  => t = t' /\ ee = ee').
Proof.
  intros. induction H; cbn;
  repeat (rewrite ?wp_bind, ?wp_ty_eqb, ?wp_ret, ?wp_fail; try destruct o; cbn; try rewrite H;
      try match goal with
      | IH : wp_freeM (infer ?g ?e) _ |- wp_freeM (infer ?g ?e) _ =>
          revert IH; apply wp_monotone; intros; subst
      | |- ?x = ?y /\ _ =>
          split
      | H : ?x = ?y /\ _ |- _ =>
          destruct H; subst
(*
          | |- forall t, ?e =>
          intro
*)
      end; try reflexivity).
      - intros. apply wp_bind. revert IHtpb. assert (Hteq : vt = t0). admit.
        subst. apply wp_monotone. intro. destruct o. split; destruct H0; subst; reflexivity.
      - intro. assert (Hteq: t1 = t0). admit.
        split; rewrite Hteq; intuition.
Admitted.

