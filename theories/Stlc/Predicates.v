(******************************************************************************)
(* Copyright (c) 2023 Steven Keuchel                                          *)
(* All rights reserved.                                                       *)
(*                                                                            *)
(* Redistribution and use in source and binary forms, with or without         *)
(* modification, are permitted provided that the following conditions are     *)
(* met:                                                                       *)
(*                                                                            *)
(* 1. Redistributions of source code must retain the above copyright notice,  *)
(*    this list of conditions and the following disclaimer.                   *)
(*                                                                            *)
(* 2. Redistributions in binary form must reproduce the above copyright       *)
(*    notice, this list of conditions and the following disclaimer in the     *)
(*    documentation and/or other materials provided with the distribution.    *)
(*                                                                            *)
(* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        *)
(* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED  *)
(* TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR *)
(* PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR          *)
(* CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,      *)
(* EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,        *)
(* PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR         *)
(* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF     *)
(* LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING       *)
(* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS         *)
(* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.               *)
(******************************************************************************)

From Coq Require Import
  Classes.Morphisms
  Classes.Morphisms_Prop
  Classes.RelationClasses
  Relations.Relation_Definitions
  Strings.String.
From iris Require
  bi.derived_connectives
  bi.interface
  proofmode.tactics.
From stdpp Require Import
  base.
From Em Require Import
  Environment
  Prelude
  Stlc.Alloc
  Stlc.Instantiation
  Stlc.Persistence
  Stlc.Sem
  Stlc.Spec
  Stlc.Substitution
  Stlc.Worlds.

Import world.notations.

#[local] Set Implicit Arguments.
#[local] Arguments step : simpl never.
#[local] Arguments thick : simpl never.

(* #[local] Notation "Q [ ζ ]" := *)
(*   (_4 Q ζ) *)
(*     (at level 8, left associativity, *)
(*       format "Q [ ζ ]") : box_scope. *)

Module Pred.
  #[local] Notation Ėxp := (Sem Exp).

  Declare Scope pred_scope.
  Delimit Scope pred_scope with P.

  Definition Pred (w : World) : Type :=
    Assignment w -> Prop.
  Bind Scope pred_scope with Pred.

  Section Definitions.

    Definition eqₚ {T : TYPE} {A : Type} {instTA : Inst T A} :
      ⊧ T ⇢ T ⇢ Pred :=
      fun w t1 t2 ι => inst t1 ι = inst t2 ι.
    #[global] Arguments eqₚ {T A _} [w] _ _ _/.

    Definition TPB : ⊧ Ėnv ⇢ Const Exp ⇢ Ṫy ⇢ Ėxp ⇢ Pred :=
      fun w G e t ee ι => inst G ι |-- e ∷ inst t ι ~> inst ee ι.
    #[global] Arguments TPB [w] G e t ee ι/.

    #[export] Instance persist_pred : Persistent Pred :=
      fun Θ w1 P w2 θ ι2 => P (inst θ ι2).
    #[global] Arguments persist_pred Θ [w] _ [w1] _ _ /.

  End Definitions.

  Section RewriteRelations.

    Context {w : World}.

    Record bientails (P Q : Pred w) : Prop :=
      MkBientails { fromBientails : forall ι, P ι <-> Q ι }.
    Record entails (P Q : Pred w) : Prop :=
      MkEntails { fromEntails : forall ι, P ι -> Q ι }.

    #[export] Instance pred_equiv : Equiv (Pred w) := bientails.
    #[export] Instance pred_equivalence : Equivalence (≡@{Pred w}).
    Proof. firstorder. Qed.

    #[export] Instance preorder_entails : RelationClasses.PreOrder entails.
    Proof. firstorder. Qed.
    #[export] Instance subrelation_bientails_entails :
      subrelation (≡@{Pred w}) entails.
    Proof. firstorder. Qed.
    #[export] Instance subrelation_bientails_flip_entails :
      subrelation (≡@{Pred w}) (Basics.flip entails).
    Proof. firstorder. Qed.

    (* #[export] Instance proper_bientails : *)
    (*   Proper (bientails ==> bientails ==> iff) bientails. *)
    (* Proof. intuition. Qed. *)
    #[export] Instance proper_entails_bientails :
      Proper ((≡@{Pred w}) ==> (≡@{Pred w}) ==> iff) entails.
    Proof. firstorder. Qed.
    #[export] Instance proper_entails_entails :
      Proper (Basics.flip entails ==> entails ==> Basics.impl) entails.
    Proof. firstorder. Qed.

  End RewriteRelations.
  #[global] Arguments bientails {w} (_ _)%P.
  #[global] Arguments entails {w} (_ _)%P.

  Module Import proofmode.

    Import iris.bi.interface.

    Variant empₚ {w} (ι : Assignment w) : Prop :=
      MkEmp : empₚ ι.
    Variant sepₚ {w} (P Q : Pred w) (ι : Assignment w) : Prop :=
      MkSep : P ι -> Q ι -> sepₚ P Q ι.
    Variant wandₚ {w} (P Q : Pred w) (ι : Assignment w) : Prop :=
      MkWand : (P ι -> Q ι) -> wandₚ P Q ι.
    Variant persistently {w} (P : Pred w) (ι : Assignment w) : Prop :=
      MkPersistently : P ι -> persistently P ι.

    #[export] Instance ofe_dist_pred {w} : ofe.Dist (Pred w) :=
      ofe.discrete_dist.

    (* Iris defines [bi_later_mixin_id] for BI algebras without later. However,
       the identity function as later still causes some later-specific
       typeclasses to be picked. We just define our own trivial modality and
       mixin to avoid that. *)
    Variant later {w} (P : Pred w) (ι : Assignment w) : Prop :=
      MkLater : P ι -> later P ι.

    Canonical bi_pred {w : World} : bi.
    Proof.
      refine
        {| bi_car := Pred w;
           bi_entails := entails;
           bi_emp := empₚ;
           bi_pure P _ := P;
           bi_and P Q ι := P ι /\ Q ι;
           bi_or P Q ι := P ι \/ Q ι;
           bi_impl P Q ι := P ι -> Q ι;
           bi_forall A f ι := forall a, f a ι;
           bi_exist A f ι := exists a, f a ι;
           bi_sep := sepₚ;
           bi_wand := wandₚ;
           bi_persistently := persistently;
           bi_later := later;
        |}.
      all: abstract firstorder.
    Defined.

    #[export] Instance persistent_pred {w} {P : Pred w} :
      derived_connectives.Persistent P.
    Proof. constructor. intros ι HP. constructor. exact HP. Qed.

    #[export] Instance affine_pred {w} {P : Pred w} :
      derived_connectives.Affine P.
    Proof. constructor. intros ι HP. constructor. Qed.

  End proofmode.

  Module Import notations.

    Import iris.bi.interface.
    Import iris.bi.derived_connectives.

    Notation "P ⊣⊢ₚ Q" :=
      (@equiv (bi_car (@bi_pred _)) (@pred_equiv _) P%P Q%P)
        (at level 95).
    Notation "(⊣⊢ₚ)" :=
      (@equiv (bi_car (@bi_pred _)) (@pred_equiv _))
        (only parsing).

    Notation "P ⊢ₚ Q" := (@bi_entails (@bi_pred _) P%P Q%P) (at level 95).
    Notation "(⊢ₚ)" := (@bi_entails (@bi_pred _)) (only parsing).

    Notation "⊤ₚ" := (@bi_pure (@bi_pred _) True) : pred_scope.
    Notation "⊥ₚ" := (@bi_pure (@bi_pred _) False) : pred_scope.
    Notation "P <->ₚ Q" := (@bi_iff (@bi_pred _) P%P Q%P) (at level 94) : pred_scope.
    Notation "P ->ₚ Q"  := (@bi_impl (@bi_pred _) P%P Q%P) (at level 94, right associativity) : pred_scope.
    Notation "P /\ₚ Q"  := (@bi_and (@bi_pred _) P%P Q%P) (at level 80, right associativity) : pred_scope.
    Notation "P \/ₚ Q"  := (@bi_or (@bi_pred _) P%P Q%P) (at level 85, right associativity) : pred_scope.

    Infix "=ₚ" := eqₚ (at level 70, no associativity) : pred_scope.

    Notation "∀ₚ x .. y , P" :=
      (@bi_forall (@bi_pred _) _ (fun x => .. (@bi_forall (@bi_pred _) _ (fun y => P%P)) ..))
      (at level 200, x binder, y binder, right associativity,
        format "'[ ' '[ ' ∀ₚ  x .. y ']' ,  '/' P ']'") : pred_scope.
    Notation "∃ₚ x .. y , P" :=
      (@bi_exist (@bi_pred _) _ (fun x => .. (@bi_exist (@bi_pred _) _ (fun y => P%P)) ..))
      (at level 200, x binder, y binder, right associativity,
        format "'[ ' '[ ' ∃ₚ  x .. y ']' ,  '/' P ']'") : pred_scope.

    Notation "G |--ₚ E ; T ~> EE" :=
      (TPB G E T EE) (at level 70, no associativity) : pred_scope.

  End notations.

  Lemma bientails_unfold [w] (P Q : Pred w) :
    (P ⊣⊢ₚ Q) <-> forall ι, P ι <-> Q ι.
  Proof. firstorder. Qed.
  Lemma entails_unfold [w] (P Q : Pred w) :
    (P ⊢ₚ Q) <-> forall ι, P ι -> Q ι.
  Proof. firstorder. Qed.
  Lemma sep_unfold w (P Q : Pred w) :
    ∀ ι, interface.bi_sep P Q ι ↔ (P ι /\ Q ι).
  Proof. firstorder. Qed.
  Lemma wand_unfold w (P Q : Pred w) :
    ∀ ι, interface.bi_wand P Q ι ↔ (P ι → Q ι).
  Proof. firstorder. Qed.
  Lemma intuitionistically_unfold w (P : Pred w) :
    ∀ ι, @derived_connectives.bi_intuitionistically _ P ι <-> P ι.
  Proof. firstorder. Qed.

  Create HintDb punfold.
  #[export] Hint Rewrite bientails_unfold entails_unfold sep_unfold wand_unfold
    intuitionistically_unfold
    (@inst_persist Ėnv Env _ _ _)
    (@inst_persist Ėxp Exp _ _ _)
    (@inst_persist Ṫy Ty _ _ _)
    (@inst_lift Ėnv Env _ _ _)
    (@inst_lift Ėxp Exp _ _ _)
    (@inst_lift Ṫy Ty _ _ _)
    (@inst_thin Sub _ Sub.lk_thin_sub)
    @inst_refl @inst_trans @inst_insert
    @Sem.inst_pure
    @ėxp.inst_var @ėxp.inst_true @ėxp.inst_false @ėxp.inst_ifte @ėxp.inst_absu
    @ėxp.inst_abst @ėxp.inst_app : punfold.

  Ltac punfold_connectives :=
    change (@interface.bi_and (@bi_pred _) ?P ?Q ?ι) with (P ι /\ Q ι) in *;
    change (@interface.bi_or (@bi_pred _) ?P ?Q ?ι) with (P ι \/ Q ι) in *;
    change (@interface.bi_impl (@bi_pred _) ?P ?Q ?ι) with (P ι -> Q ι) in *;
    change (@derived_connectives.bi_iff (@bi_pred _) ?P ?Q ?ι) with (iff (P ι) (Q ι)) in *;
    change (@interface.bi_pure (@bi_pred _) ?P _) with P in *;
    change (@interface.bi_forall (@bi_pred _) ?A ?P) with (fun ι => forall a : A, P a ι) in *;
    change (@interface.bi_exist (@bi_pred _) ?A ?P) with (fun ι => exists a : A, P a ι) in *;
    change (@persist Pred persist_pred _ _ ?P _ ?θ ?ι) with (P (inst θ ι)) in *;
    try progress (cbn beta).

  Ltac pred_unfold :=
    repeat
      (punfold_connectives;
       try rewrite_db punfold; auto 1 with typeclass_instances;
       cbn [eqₚ TPB inst inst_ty inst_env] in *;
       (* repeat rewrite ?inst_persist, ?inst_lift, ?inst_refl, ?inst_trans, *)
       (*   ?inst_insert, ?ėxp.inst_var, ?ėxp.inst_true, ?ėxp.inst_false, *)
       (*   ?ėxp.inst_absu, ?ėxp.inst_abst, ?ėxp.inst_app, ?ėxp.inst_ifte in *; *)
       try
         match goal with
         | |- forall ι : Assignment _, _ =>
             let ι := fresh "ι" in
             intro ι; pred_unfold;
             first [clear ι | revert ι]
         | |- @interface.bi_emp_valid (@bi_pred _) _ => constructor; intros ι _; cbn
         | |- @interface.bi_entails (@bi_pred _) _ _ => constructor; intros ι; cbn
         (* | H: context[@inst ?AT ?A ?I ?w ?x ?ι] |- _ => *)
         (*     is_var x; generalize (@inst AT A I w x ι); *)
         (*     clear x; intro x; subst *)
         | |- context[@inst ?AT ?A ?I ?w ?x ?ι] =>
             is_var x; generalize (@inst AT A I w x ι);
             clear x; intro x; subst
         end).

  Section Lemmas.

    Import iris.bi.interface.

    Create HintDb obligation.
    #[local] Hint Rewrite @inst_refl @inst_trans : obligation.

    #[local] Ltac obligation :=
      cbv [Proper flip respectful pointwise_relation forall_relation];
      repeat (autorewrite with obligation in *; cbn in *; intros; subst; pred_unfold);
      repeat
        (match goal with
         | H: _ ⊢ₚ _ |- _ => destruct H as [H]
         | H: _ ⊣⊢ₚ _ |- _ => destruct H as [H]
         | H: forall (H : ?A), _, a : ?A |- _ =>
           specialize (H a); autorewrite with obligation in H; cbn in H
         | |- (forall _ : ?A, _) <-> (forall _ : ?A, _) =>
             apply all_iff_morphism; intro; autorewrite with obligation; cbn
         | |- (exists _ : ?A, _) <-> (exists _ : ?A, _) =>
             apply ex_iff_morphism; intro; autorewrite with obligation; cbn
         (* | |- _ ⊣⊢ₚ _ => constructor; cbn; intros *)
         (* | |- _ ⊢ₚ _ => constructor; cbn; intros *)
         end);
      try easy; try (intuition; fail); try (intuition congruence; fail).
    #[local] Obligation Tactic := obligation.

    #[local] Hint Rewrite <- @tactics.forall_and_distr : obligation.

    #[export] Instance proper_persist_bientails {Θ w} :
      Proper ((⊣⊢ₚ) ==> forall_relation (fun _ => eq ==> (⊣⊢ₚ)))
      (@persist Pred persist_pred Θ w).
    Proof. obligation. Qed.

    Lemma split_bientails {w} (P Q : Pred w) :
      (P ⊣⊢ₚ Q) <-> (P ⊢ₚ Q) /\ (Q ⊢ₚ P).
    Proof. obligation. Qed.
    Lemma impl_and_adjoint {w} (P Q R : Pred w) : (P /\ₚ Q ⊢ₚ R) <-> (P ⊢ₚ Q ->ₚ R).
    Proof. obligation. Qed.
    Lemma and_comm {w} (P Q : Pred w) : P /\ₚ Q  ⊣⊢ₚ  Q /\ₚ P.
    Proof. obligation. Qed.
    Lemma and_assoc {w} (P Q R : Pred w) : (P /\ₚ Q) /\ₚ R  ⊣⊢ₚ  P /\ₚ (Q /\ₚ R).
    Proof. obligation. Qed.
    Lemma and_true_l {w} (P : Pred w) : ⊤ₚ /\ₚ P ⊣⊢ₚ P.
    Proof. obligation. Qed.
    Lemma and_true_r {w} (P : Pred w) : P /\ₚ ⊤ₚ ⊣⊢ₚ P.
    Proof. obligation. Qed.
    Lemma and_false_l {w} (P : Pred w) : ⊥ₚ /\ₚ P ⊣⊢ₚ ⊥ₚ.
    Proof. obligation. Qed.
    Lemma and_false_r {w} (P : Pred w) : P /\ₚ ⊥ₚ ⊣⊢ₚ ⊥ₚ.
    Proof. obligation. Qed.
    Lemma impl_true_l {w} (P : Pred w) : ⊤ₚ ->ₚ P ⊣⊢ₚ P.
    Proof. obligation. Qed.
    Lemma impl_true_r {w} (P : Pred w) : P ->ₚ ⊤ₚ ⊣⊢ₚ ⊤ₚ.
    Proof. obligation. Qed.
    Lemma impl_false_l {w} (P : Pred w) : ⊥ₚ ->ₚ P ⊣⊢ₚ ⊤ₚ.
    Proof. obligation. Qed.
    (* Lemma false_l {w} (P : Pred w) : ⊥ₚ ⊢ₚ P. *)
    (* Proof. obligation. Qed. *)
    (* Lemma true_r {w} (P : Pred w) : P ⊢ₚ ⊤ₚ. *)
    (* Proof. obligation. Qed. *)
    (* Lemma impl_forget {w} (P Q R : Pred w) : P ⊢ₚ R -> P ⊢ₚ (Q ->ₚ R). *)
    (* Proof. obligation. Qed. *)
    Lemma impl_and [w] (P Q R : Pred w) : ((P /\ₚ Q) ->ₚ R) ⊣⊢ₚ (P ->ₚ Q ->ₚ R).
    Proof. obligation. Qed.

    (* Lemma forall_l {I : Type} {w} (P : I -> Pred w) Q : *)
    (*   (exists x : I, P x ⊢ₚ Q) -> (∀ x : I, P x)%I ⊢ₚ Q. *)
    (* Proof. obligation. firstorder. Qed. *)
    (* Lemma forall_r {I : Type} {w} P (Q : I -> Pred w) : *)
    (*   (P ⊢ₚ (∀ₚ x : I, Q x)) <-> (forall x : I, P ⊢ₚ Q x). *)
    (* Proof. obligation. firstorder. Qed. *)

    Lemma exists_l {I : Type} {w} (P : I -> Pred w) (Q : Pred w) :
      (forall x : I, P x ⊢ₚ Q) -> (∃ₚ x : I, P x) ⊢ₚ Q.
    Proof. obligation; firstorder. Qed.
    Lemma exists_r {I : Type} {w} P (Q : I -> Pred w) :
      (exists x : I, P ⊢ₚ Q x) -> P ⊢ₚ (∃ₚ x : I, Q x).
    Proof. obligation; firstorder. Qed.
    #[global] Arguments exists_r {I w P Q} _.

    Lemma wand_is_impl [w] (P Q : Pred w) :
      (P -∗ Q)%I ⊣⊢ₚ (P ->ₚ Q).
    Proof. obligation. Qed.

    Lemma pApply {w} {P Q R : Pred w} :
      P ⊢ₚ Q -> Q ⊢ₚ R -> P ⊢ₚ R.
    Proof. now transitivity Q. Qed.

    Lemma pApply_r {w} {P Q R : Pred w} :
      Q ⊢ₚ R -> P ⊢ₚ Q -> P ⊢ₚ R.
    Proof. now transitivity Q. Qed.

    Section Eq.

      Context {T A} {instTA : Inst T A}.

      Lemma eqₚ_intro {w} (t : T w) : ⊢ (t =ₚ t)%P.
      Proof. obligation. Qed.

      Lemma eqₚ_refl {w} (t : T w) : t =ₚ t ⊣⊢ₚ ⊤ₚ.
      Proof. obligation. Qed.

      Lemma eqₚ_sym {w} (s t : T w) : s =ₚ t ⊣⊢ₚ t =ₚ s.
      Proof. obligation. Qed.

      Lemma eqₚ_trans {w} (s t u : T w) : s =ₚ t /\ₚ t =ₚ u ⊢ₚ s =ₚ u.
      Proof. obligation. Qed.

    End Eq.
    #[global] Arguments eqₚ_trans {T A _ w} s t u.

    Lemma peq_ty_noconfusion {w} (t1 t2 : Ṫy w) :
      t1 =ₚ t2 ⊣⊢ₚ
            match t1 , t2 with
            | ṫy.var  _       , _               => t1 =ₚ t2
            | _               , ṫy.var _        => t1 =ₚ t2
            | ṫy.bool         , ṫy.bool         => ⊤ₚ
            | ṫy.func t11 t12 , ṫy.func t21 t22 => t11 =ₚ t21 /\ₚ t12 =ₚ t22
            | _               , _               => ⊥ₚ
            end.
    Proof. destruct t1, t2; obligation. Qed.

    Lemma eq_pair
      {AT BT : TYPE} {A B : Type} {instA : Inst AT A} {instB : Inst BT B}
      [w] (a1 a2 : AT w) (b1 b2 : BT w) :
      (a1,b1) =ₚ (a2,b2) ⊣⊢ₚ ((a1 =ₚ a2) /\ₚ (b1 =ₚ b2)).
    Proof.
      pred_unfold. intros ι; cbn. split.
      - now injection 1.
      - intros []. now f_equal.
    Qed.

    Section Persist.

      Lemma persist_eq {T : TYPE} {persR : Persistence.Persistent T}
        {A : Type} {instTA : Inst T A} {instPersistTA : InstPersist T A}
        {Θ : SUB} {w0 w1} (θ : Θ w0 w1) (t1 t2 : T w0) :
        persist (t1 =ₚ t2) θ ⊣⊢ₚ persist t1 θ =ₚ persist t2 θ.
      Proof.
        pred_unfold. unfold persist, persist_pred. intros ι.
        now rewrite !inst_persist.
      Qed.

      Context {Θ : SUB}.

      (* We could define a PersistLaws instance for the Pred type, but that's
         requires functional extensionality. Instead, we provide similar
         lemmas that use bientailment instead of Leibniz equality and thus
         avoid functional extensionality. *)
      Lemma persist_pred_refl `{lkReflΘ : LkRefl Θ} [w] (P : Pred w) :
        persist P refl ⊣⊢ₚ P.
      Proof. obligation. Qed.
      Lemma persist_pred_trans `{lktransΘ : LkTrans Θ}
        {w0 w1 w2} (θ1 : Θ w0 w1) (θ2 : Θ w1 w2) (P : Pred w0) :
        persist P (θ1 ⊙ θ2) ⊣⊢ₚ persist (persist P θ1) θ2.
      Proof. obligation. Qed.
      Lemma persist_and {w0 w1} (θ : Θ w0 w1) (P Q : Pred w0) :
        persist (P /\ₚ Q) θ ⊣⊢ₚ persist P θ /\ₚ persist Q θ.
      Proof. obligation. Qed.
      Lemma persist_impl {w0 w1} (θ : Θ w0 w1) (P Q : Pred w0) :
        persist (P ->ₚ Q) θ ⊣⊢ₚ (persist P θ ->ₚ persist Q θ).
      Proof. obligation. Qed.
      Lemma persist_wand {w0 w1} (θ : Θ w0 w1) (P Q : Pred w0) :
        persist (interface.bi_wand P Q) θ ⊣⊢ₚ interface.bi_wand (persist P θ) (persist Q θ).
      Proof. obligation. Qed.
      Lemma persist_false {w0 w1} (θ : Θ w0 w1) :
        persist ⊥ₚ θ ⊣⊢ₚ ⊥ₚ.
      Proof. obligation. Qed.
      Lemma persist_true {w0 w1} (θ : Θ w0 w1) :
        persist ⊤ₚ θ ⊣⊢ₚ ⊤ₚ.
      Proof. obligation. Qed.
      Lemma persist_forall [A] [w0 w1] (θ : Θ w0 w1) (Q : A -> Pred w0) :
        persist (∀ₚ a : A, Q a) θ ⊣⊢ₚ (∀ₚ a : A, persist (Q a) θ).
      Proof. obligation. Qed.
      Lemma persist_exists [A] [w0 w1] (θ : Θ w0 w1) (Q : A -> Pred w0) :
        persist (∃ₚ a : A, Q a) θ ⊣⊢ₚ (∃ₚ a : A, persist (Q a) θ).
      Proof. obligation. Qed.

      Lemma persist_tpb {w0 w1} (θ : Θ w0 w1) G (e : Exp) (t : Ṫy w0) (ee : Ėxp w0) :
        persist (G |--ₚ e; t ~> ee) θ ⊣⊢ₚ
        persist G θ |--ₚ e; persist t θ ~> persist ee θ.
      Proof. obligation. Qed.

    End Persist.

  End Lemmas.

  Module Acc.
    Import (hints) Sub.
    Section WithAccessibilityRelation.
      Context {Θ : SUB}.

      Definition wp {w0 w1} (θ : Θ w0 w1) (Q : Pred w1) : Pred w0 :=
        fun ι0 => exists (ι1 : Assignment w1), inst θ ι1 = ι0 /\ Q ι1.
      Definition wlp {w0 w1} (θ : Θ w0 w1) (Q : Pred w1) : Pred w0 :=
        fun ι0 => forall (ι1 : Assignment w1), inst θ ι1 = ι0 -> Q ι1.

      #[global] Arguments wp {_ _} _ _ ι0/.
      #[global] Arguments wlp {_ _} _ _ ι0/.

      #[export] Instance proper_wp_bientails {w0 w1} (θ : Θ w0 w1) :
        Proper ((⊣⊢ₚ) ==> (⊣⊢ₚ)) (wp θ).
      Proof. firstorder. Qed.

      #[export] Instance proper_wp_entails {w0 w1} (θ : Θ w0 w1) :
        Proper ((⊢ₚ) ==> (⊢ₚ)) (wp θ).
      Proof. firstorder. Qed.

      #[export] Instance proper_wlp_bientails {w0 w1} (θ : Θ w0 w1) :
        Proper ((⊣⊢ₚ) ==> (⊣⊢ₚ)) (wlp θ).
      Proof. firstorder. Qed.

      #[export] Instance proper_wlp_entails {w0 w1} (θ : Θ w0 w1) :
        Proper ((⊢ₚ) ==> (⊢ₚ)) (wlp θ).
      Proof. firstorder. Qed.

      Lemma wp_refl {reflΘ : Refl Θ} {lkreflΘ : LkRefl Θ}
        {w} (Q : Pred w) : wp refl Q ⊣⊢ₚ Q.
      Proof.
        unfold wp; pred_unfold. intros ι; split.
        - intros (ι' & Heq & HQ). now subst.
        - intros HQ. exists ι. easy.
      Qed.

      Lemma wp_trans {transR : Trans Θ} {lktransΘ : LkTrans Θ}
        {w0 w1 w2} (θ1 : Θ w0 w1) (θ2 : Θ w1 w2) Q :
        wp (θ1 ⊙ θ2) Q ⊣⊢ₚ wp θ1 (wp θ2 Q).
      Proof.
        unfold wp; pred_unfold. intros ι; split.
        - intros (ι2 & Heq & HQ). eauto.
        - intros (ι1 & Heq1 & ι2 & Heq2 & HQ). subst. eauto.
      Qed.

      Lemma wp_false {w0 w1} (θ : Θ w0 w1) :
        wp θ ⊥ₚ ⊣⊢ₚ ⊥ₚ.
      Proof. firstorder. Qed.

      Lemma and_wp_l {w0 w1} (θ : Θ w0 w1) P Q :
        wp θ P /\ₚ Q ⊣⊢ₚ wp θ (P /\ₚ persist Q θ).
      Proof.
        unfold wp; pred_unfold. split.
        - intros [(ι1 & <- & HP) HQ]. eauto.
        - intros (ι1 & <- & HP & HQ). eauto.
      Qed.

      Lemma and_wp_r {w0 w1} (θ : Θ w0 w1) (P : Pred w0) (Q : Pred w1) :
        P /\ₚ wp θ Q ⊣⊢ₚ wp θ (persist P θ /\ₚ Q).
      Proof. now rewrite and_comm, and_wp_l, and_comm. Qed.

      Lemma wp_thick {thickΘ : Thick Θ} {lkThickΘ : LkThick Θ}
        {w α} (αIn : world.In α w) (t : Ṫy (w - α)) (Q : Pred (w - α)) :
        wp (thick α t) Q ⊣⊢ₚ ṫy.var αIn =ₚ persist t (thin (Θ := Sub) α) /\ₚ persist Q (thin (Θ := Sub) α).
      Proof.
        unfold wp; pred_unfold. intros ι. split.
        - intros (ι1 & Heq & HQ). subst.
          now rewrite inst_thick, env.remove_insert, env.lookup_insert.
        - intros [Heq HQ]. exists (env.remove α ι αIn).
          now rewrite inst_thick, <- Heq, env.insert_remove.
      Qed.

      Lemma wlp_refl {reflΘ : Refl Θ} {lkreflΘ : LkRefl Θ}
        {w} (Q : Pred w) : wlp refl Q ⊣⊢ₚ Q.
      Proof.
        unfold wlp; pred_unfold. intros ι. split.
        - intros HQ. auto.
        - intros HQ ? <-. auto.
      Qed.

      Lemma wlp_trans {transR : Trans Θ} {lktransΘ : LkTrans Θ}
        {w0 w1 w2} (θ1 : Θ w0 w1) (θ2 : Θ w1 w2) Q :
        wlp (θ1 ⊙ θ2) Q ⊣⊢ₚ wlp θ1 (wlp θ2 Q).
      Proof.
        unfold wlp; pred_unfold. intros ι. split.
        - intros HQ ι1 Heq1 ι2 Heq2. subst; auto.
        - intros HQ ι2 Heq. subst; eauto.
      Qed.

      Lemma wlp_true {w0 w1} (θ : Θ w0 w1) :
        wlp θ ⊤ₚ ⊣⊢ₚ ⊤ₚ.
      Proof. firstorder. Qed.

      Lemma wlp_and {w0 w1} (θ : Θ w0 w1) P Q :
        wlp θ P /\ₚ wlp θ Q ⊣⊢ₚ wlp θ (P /\ₚ Q).
      Proof. firstorder. Qed.

      Lemma wp_or {w0 w1} (θ : Θ w0 w1) P Q :
        wp θ P \/ₚ wp θ Q ⊣⊢ₚ wp θ (P \/ₚ Q).
      Proof. firstorder. Qed.

      Lemma wp_mono {w0 w1} (θ : Θ w0 w1) P Q:
        wlp θ (interface.bi_wand P Q) ⊢ₚ interface.bi_wand (wp θ P) (wp θ Q).
      Proof. firstorder. Qed.

      Lemma wlp_mono {w0 w1} (θ : Θ w0 w1) P Q :
        wlp θ (interface.bi_wand P Q) ⊢ₚ interface.bi_wand (wlp θ P) (wlp θ Q).
      Proof. firstorder. Qed.

      Lemma entails_wlp {w0 w1} (θ : Θ w0 w1) P Q :
        (persist P θ ⊢ₚ Q) <-> (P ⊢ₚ wlp θ Q).
      Proof.
        unfold wlp; pred_unfold. split; intros HPQ.
        - intros ι0 HP ι1 <-. revert HP. apply HPQ.
        - intros ι1 HP. now apply (HPQ (inst θ ι1)).
      Qed.

      Lemma entails_wp {w0 w1} (θ : Θ w0 w1) P Q :
        (P ⊢ₚ persist Q θ) <-> (wp θ P ⊢ₚ Q).
      Proof.
        unfold wp; pred_unfold. split; intros HPQ.
        - intros ι0 (ι1 & <- & HP). now apply HPQ.
        - intros ι1 HP. apply (HPQ (inst θ ι1)).
          exists ι1. split; auto.
      Qed.

      Lemma wp_impl {w0 w1} (θ1 : Θ w0 w1) (P : Pred _) (Q : Pred _) :
        (wp θ1 P ->ₚ Q) ⊣⊢ₚ wlp θ1 (P ->ₚ persist Q θ1).
      Proof.
        unfold wp, wlp; pred_unfold. intros ι0; split.
        - intros H ι1 <- HP. apply H. now exists ι1.
        - intros HPQ (ι1 & <- & HP). now apply HPQ.
      Qed.

      Lemma persist_wlp {w0 w1} {θ : Θ w0 w1} (P : Pred w1) :
        persist (wlp θ P) θ ⊢ₚ P.
      Proof. firstorder. Qed.

      Lemma persist_wp {w0 w1} {θ : Θ w0 w1} (P : Pred w1) :
        P ⊢ₚ persist (wp θ P) θ.
      Proof. firstorder. Qed.

      Lemma wlp_frame {w0 w1} (θ : Θ w0 w1) (P : Pred _) (Q : Pred _) :
        P ->ₚ wlp θ Q ⊣⊢ₚ wlp θ (persist P θ ->ₚ Q).
      Proof.
        unfold wlp; pred_unfold. intros ι; split.
        - intros H ι1 <- HP. now apply (H HP).
        - intros H HP ι1 <-. apply H; auto.
      Qed.

    End WithAccessibilityRelation.
    (* #[global] Opaque wp. *)
    (* #[global] Opaque wlp. *)

    (* Lemma proper_wp_step {Θ1 Θ2 : SUB} {stepΘ1 : Step Θ1} {stepΘ2 : Step Θ2} *)
    (*   {lkStepΘ1 : LkStep Θ1} {lkStepΘ2 : LkStep Θ2} *)
    (*   {w α} : *)
    (*   forall P Q : Pred (world.snoc w α), *)
    (*     P ⊣⊢ₚ Q -> wp (step (Θ := Θ1)) P ⊣⊢ₚ wp (step (Θ := Θ2)) Q. *)
    (* Proof. *)
    (*   intros P Q [PQ]. constructor. intros ι. apply base.exist_proper. *)
    (*   intros ι2. now rewrite !inst_step, PQ. *)
    (* Qed. *)

    Lemma intro_wp_step' {Θ} {stepΘ : Step Θ} {lkStepΘ : LkStep Θ}
      {w α} (P : Pred w) (Q : Pred (world.snoc w α)) (t : Ty) :
      (persist P step ⊢ₚ lift t =ₚ @ṫy.var _ α world.in_zero ->ₚ Q) ->
      (P ⊢ₚ wp (step (Θ := Θ)) Q).
    Proof.
      pred_unfold. intros H ι HP. set (ι1 := env.snoc ι α t).
      exists ι1. specialize (H ι1). rewrite inst_step in *; cbn in *.
      intuition.
    Qed.

    (* Better for iris proof mode. *)
    Lemma intro_wp_step {Θ} {stepΘ : Step Θ} {lkStepΘ : LkStep Θ}
      t {w α} (Q : Pred (world.snoc w α)) :
      wlp step (lift t =ₚ ṫy.var world.in_zero ->ₚ Q) ⊢ₚ wp (step (Θ := Θ)) Q.
    Proof. apply (intro_wp_step' t). now rewrite persist_wlp. Qed.

    Lemma wp_split  {Θ : SUB} [w0 w1] (θ : Θ w0 w1) P :
      wp θ ⊤ₚ /\ₚ wlp θ P ⊢ₚ wp θ P.
    Proof. now rewrite and_wp_l, persist_wlp, and_true_l. Qed.

    Lemma wp_sub_of {Θ : SUB} [w0 w1] (θ : Θ w0 w1) P :
      wp (Sub.of θ) P ⊣⊢ₚ wp θ P.
    Proof.
      constructor. intros ι0; cbn. apply ex_iff_morphism; intro ι1.
      apply and_iff_compat_r.
      split; intros; subst; apply env.lookup_extensional; intros α αIn;
        unfold Sub.of, inst, inst_acc, lk; cbn; now rewrite !env.lookup_tabulate.
    Qed.

    Lemma wlp_sub_of {Θ : SUB} [w0 w1] (θ : Θ w0 w1) P :
      wlp (Sub.of θ) P ⊣⊢ₚ wlp θ P.
    Proof.
      constructor. intros ι0; cbn. apply all_iff_morphism; intro ι1.
      apply imp_iff_compat_r.
      split; intros; subst; apply env.lookup_extensional; intros α αIn;
        unfold Sub.of, inst, inst_acc, lk; cbn; now rewrite !env.lookup_tabulate.
    Qed.

  End Acc.

  Section InstPred.
    Import iris.bi.derived_laws.
    Import iris.bi.interface.
    Import Stlc.Persistence.
    (* A type class for things that can be interpreted as a predicate. *)
    Class InstPred (A : TYPE) :=
      instpred : ⊧ A ⇢ Pred.
    #[global] Arguments instpred {_ _ _}.

    (* #[export] Instance instpred_option {A} `{ipA : InstPred A} : *)
    (*   InstPred (Option A) := *)
    (*   fun w o => wp_option o instpred. *)
    #[export] Instance instpred_list {A} `{ipA : InstPred A} :
      InstPred (List A) :=
      fun w =>
        fix ip xs {struct xs} :=
        match xs with
        | nil       => ⊤ₚ
        | cons y ys => instpred y /\ₚ ip ys
        end%P.
    #[local] Instance instpred_prod_ty : InstPred (Ṫy * Ṫy) :=
      fun w '(t1,t2) => eqₚ t1 t2.
    #[export] Instance instpred_unit : InstPred Unit :=
      fun w 'tt => ⊤ₚ%P.

    Lemma instpred_list_app {A} `{ipA : InstPred A} [w] (xs ys : List A w) :
      instpred (xs ++ ys) ⊣⊢ₚ instpred xs /\ₚ instpred ys.
    Proof.
      induction xs; cbn.
      - now rewrite and_true_l.
      - rewrite Pred.and_assoc. now apply bi.and_proper.
    Qed.

    Class InstPredPersist A {ipA : InstPred A} {persA : Persistent A} :=
      instpred_persist [Θ : SUB] {w0 w1} (θ : Θ w0 w1) (a : A w0) :
        instpred (persist a θ) ⊣⊢ₚ persist (instpred a) θ.
    #[global] Arguments InstPredPersist _ {_ _}.

    #[export] Instance instpred_persist_list `{InstPredPersist A} :
      InstPredPersist (List A).
    Proof.
      intros Θ w0 w1 θ xs. unfold persist, persistent_list.
      induction xs; cbn; [easy|]. now rewrite instpred_persist IHxs.
    Qed.

    #[local] Instance instpred_persist_prod_ty : InstPredPersist (Ṫy * Ṫy).
    Proof. intros Θ w0 w1 θ [τ1 τ2]; cbn. now rewrite persist_eq. Qed.

  End InstPred.

  Lemma pno_cycle {w} (t1 t2 : Ṫy w) (Hsub : ṫy.Ṫy_subterm t1 t2) :
    t1 =ₚ t2 ⊢ₚ ⊥ₚ.
  Proof.
    constructor. intros ι Heq. apply (inst_subterm ι) in Hsub.
    rewrite <- Heq in Hsub. now apply ty.no_cycle in Hsub.
  Qed.

  Lemma eqₚ_insert {w} (G1 G2 : Ėnv w) (x : string) (t1 t2 : Ṫy w) :
    G1 =ₚ G2 /\ₚ t1 =ₚ t2 ⊢ₚ
    insert (M := Ėnv w) x t1 G1 =ₚ insert (M := Ėnv w) x t2 G2.
  Proof. pred_unfold. intros []. now f_equal. Qed.

  Lemma eq_func {w} (s1 s2 t1 t2 : Ṫy w) :
    ṫy.func s1 s2 =ₚ ṫy.func t1 t2 ⊣⊢ₚ (s1 =ₚ t1) /\ₚ (s2 =ₚ t2).
  Proof. now rewrite peq_ty_noconfusion. Qed.

  #[export] Instance params_tpb : Params (@TPB) 1 := {}.
  #[export] Instance params_ifte : Params (@ėxp.ifte) 1 := {}.
  #[export] Instance params_eqₚ : Params (@eqₚ) 4 := {}.
  #[export] Instance params_persist : Params (@persist) 4 := {}.

  Section AccModality.

    Import iris.proofmode.tactics.

    Context {Θ : SUB} [w0 w1] (θ : Θ w0 w1).

    Class IntoAcc (P : Pred w0) (Q : Pred w1) :=
      into_acc : P ⊢ Acc.wlp θ Q.

    #[export] Instance into_acc_default (P : Pred w0) : IntoAcc P (persist P θ).
    Proof. constructor. cbn. intros ι0 HP ι1 <-. apply HP. Qed.

    Definition modality_wlp_mixin :
      modality_mixin (Acc.wlp θ)
        (MIEnvTransform IntoAcc)
        (MIEnvTransform IntoAcc).
    Proof. firstorder. Qed.

    Definition modality_wlp : modality bi_pred bi_pred :=
      Modality _ (modality_wlp_mixin).

    #[export] Instance from_modal_wlp P :
      FromModal True modality_wlp (Acc.wlp θ P) (Acc.wlp θ P) P.
    Proof. firstorder. Qed.

  End AccModality.

  #[global] Arguments IntoAcc {Θ} [w0 w1] θ P Q.
  #[global] Arguments into_acc {Θ} [w0 w1] θ P Q {_}.
  #[global] Hint Mode IntoAcc + + + + - - : typeclass_instances.

  Import (hints) Sub.

  Create HintDb predsimpl.
  #[export] Hint Rewrite
    (@persist_eq Ėnv _ _ _ _)
    (@persist_eq Ṫy _ _ _ _)
    (@persist_refl Ėnv _ _)
    (@persist_refl Ṫy _ _)
    (@persist_trans Ėnv _ _)
    (@persist_trans Ṫy _ _)
    @Acc.wlp_refl
    @Acc.wlp_trans
    @Acc.wlp_true
    @Acc.wp_false
    @Acc.wp_refl
    @Acc.wp_trans
    @Sem.persist_pure
    @and_false_l
    @and_false_r
    @and_true_l
    @and_true_r
    @eq_func
    @eqₚ_refl
    @impl_and
    @impl_false_l
    @impl_true_l
    @impl_true_r
    @lift_insert
    @lk_refl
    @lk_step
    @lk_trans
    @persist_and
    @persist_false
    @persist_insert
    @persist_lift
    @persist_pred_refl
    @persist_pred_trans
    @persist_tpb
    @persist_true
    @trans_refl_r
    : predsimpl.
  #[export] Hint Rewrite <- @eqₚ_insert : predsimpl.

  Ltac predsimpl :=
    repeat
      (try (progress cbn); unfold _4;
       change_no_check (@gmap.gmap string _ _ (Ṫy ?w)) with (Ėnv w) in *;
       repeat
         match goal with
         | |- context[fun w : World => Ṫy w] =>
             change_no_check (fun w : World => Ṫy w) with Ṫy
         | |- context[fun w : World => Sem ?X w] =>
             change_no_check (fun w : World => Sem X w) with (Sem X)
         | |- context[fun w : World => prod (?A w) (?B w)] =>
             change_no_check (fun w : World => prod (A w) (B w)) with (Prod A B)

         | |- Acc.wp ?θ _ ⊣⊢ₚ Acc.wp ?θ _ =>
             apply Acc.proper_wp_bientails
         | |- Acc.wlp ?θ _ ⊣⊢ₚ Acc.wlp ?θ _ =>
             apply Acc.proper_wlp_bientails
         end;
       try easy;
       repeat rewrite_db predsimpl;
       repeat rewrite ?trans_refl_r, ?persist_eq, ?persist_lift,
         ?persist_pred_refl, ?persist_tpb, ?persist_trans, ?persist_trans,
         <- ?persist_pred_trans;
       auto 1 with typeclass_instances;
       repeat
         match goal with
         | |- context[@persist ?A ?I ?Θ ?w0 ?x ?w1 ?θ] =>
             is_var x; generalize (@persist A I Θ w0 x w1 θ); clear x; intros x;
             try (clear w0 θ)
         | |- context[@lk ?Θ (world.snoc ?w0 ?α) ?w1 ?θ ?α world.in_zero] =>
             is_var θ;
             generalize (@lk Θ (world.snoc w0 α) w1 θ α world.in_zero);
             clear θ w0; intros ?t
         end).

End Pred.
Export Pred (Pred).
