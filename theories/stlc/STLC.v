Require Import List.
Import ListNotations.
Require Import String.
From Em Require Import
     Definitions Context Environment.
Import ctx.notations.

(* =================================== *)
(*  The Simply-Typed Lambda Calculus   *)
(*      extended with Booleans         *)
(* =================================== *)

(* ===== Types ===== *)

Inductive ty : Type :=
  | ty_bool : ty
  | ty_func : ty -> ty -> ty.

Derive NoConfusion for ty.
(* Print noConfusion_ty_obligation_1. *)
(* Print NoConfusion_ty. *)

Inductive Ty (Σ : Ctx nat) : Type :=
  | Ty_bool : Ty Σ
  | Ty_func : Ty Σ -> Ty Σ -> Ty Σ
  | Ty_hole : forall (i : nat), i ∈ Σ -> Ty Σ.

Definition ty_eqb (a b : ty) : {a = b} + {a <> b}.
Proof. decide equality. Defined.

(* ===== Terms / Expressions ===== *)

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

(* ===== Typing Context ===== *)

Definition env := list (string * ty).

Definition Env Σ := list (string * Ty Σ).

(* Context lookup *)
Fixpoint value {X} (var : string) (ctx : list (string * X)) : option X :=
  match ctx with
  | nil => None
  | (var', val) :: ctx' =>
      if (string_dec var var') then Some val else (value var ctx')
  end.

(* ===== Typing relation ===== *)

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
  | tpb_absu : forall v vt g e e' t,
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

(* (λx . x) : Bool → Bool  ... is well-typed *)
Example id_bool_well_typed :
  nil |-- (e_absu "x" (e_var "x")) ; (ty_func ty_bool ty_bool) ~> (e_abst "x" ty_bool (e_var "x")).
Proof. repeat constructor. Qed.

Inductive freeM (A : Type) : Type :=
  | ret_free           : A -> freeM A
  | fail_free          : freeM A
  | bind_asserteq_free : ty -> ty -> freeM A -> freeM A
  | bind_exists_free   : (ty -> freeM A) -> freeM A.

Inductive FreeM (A : Ctx nat -> Type) (Σ : Ctx nat) : Type :=
  | Ret_Free           : A Σ -> FreeM A Σ
  | Fail_Free          : FreeM A Σ
  | Bind_AssertEq_Free : Ty Σ -> Ty Σ -> FreeM A Σ -> FreeM A Σ
  | Bind_Exists_Free   : forall (i : nat), FreeM A (Σ ▻ i) -> FreeM A Σ.

Inductive SolvedM (A : Ctx nat -> Type) (Σ : Ctx nat) : Type :=
  | Ret_Solved           : A Σ -> SolvedM A Σ
  | Fail_Solved          : SolvedM A Σ
  | Bind_Exists_Solved   : forall (i : nat), SolvedM A (Σ ▻ i) -> SolvedM A Σ.

Inductive solvedM (A : Type) : Type :=
  | ret_solved           : A -> solvedM A
  | fail_solved          : solvedM A
  | bind_exists_solved   : (ty -> solvedM A) -> solvedM A.

Definition Assignment : TYPE :=
  env.Env (fun _ => ty).

Fixpoint compose {w1 w2 : Ctx nat} (r12 : Accessibility w1 w2)
  : Assignment w2 -> Assignment w1 :=
  match r12 in (Accessibility _ c0) return (Assignment c0 -> Assignment w1) with
  | acc.refl _ => fun X0 : Assignment w1 => X0
  | acc.fresh _ α Σ₂ a0 =>
      fun X0 : Assignment Σ₂ =>
        match env.snocView (compose a0 X0) with
        | env.isSnoc E _ => E
        end
  end.

Lemma compose_refl : forall w ass,
    compose (acc.refl w) ass = ass.
Proof. easy. Qed.

Lemma compose_trans {w1 w2 w3 : Ctx nat} : forall ass r12 r23,
  compose r12 (compose r23 ass) = compose (@acc.trans w1 w2 w3 r12 r23) ass.
Proof. intros. induction r12. auto. cbn. rewrite IHr12. reflexivity. Qed.


Definition Lifted (A : Type) : TYPE :=
  fun Σ => Assignment Σ -> A.

Definition pure {A} (a : A) : Valid (Lifted A) := fun _ _ => a.

Definition apply : forall a b, ⊢ (Lifted (a -> b)) -> Lifted a -> Lifted b.
Proof. intros. unfold Lifted, Valid, Impl. intros. auto. Defined.

(* TODO: turn this into the Inst typeclass (See Katamaran) *)
(* has instances for Lifted, Prod, Ty, Sum, Option, Unit, ... *)
Fixpoint applyassign {w} (t : Ty w) (ass : Assignment w) : ty :=
  match t with
  | Ty_bool _ => ty_bool
  | Ty_func _ σ τ =>
      let σ' := applyassign σ ass in
      let τ' := applyassign τ ass in
      ty_func σ' τ'
  | Ty_hole _ _ i => env.lookup ass i
  end.
