(******************************************************************************)
(* Copyright (c) 2022 Steven Keuchel                                          *)
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
  Program.Equality
  Program.Tactics.
From Equations Require Import
  Equations.
From Em Require Import
  Context
  Definitions
  Environment
  Prelude
  STLC
  Substitution
  Triangular
  Unification.

Import ctx.notations.
Import SigTNotations.

Set Implicit Arguments.

#[local] Arguments Ty_hole {Σ i} xIn.
#[local] Arguments Ty_bool {Σ}.
#[local] Arguments Ty_func {Σ}.
#[local] Open Scope indexed_scope.

Reserved Notation "w1 ⊒ w2" (at level 80).

#[local] Notation "□ A" := (Box Tri A) (at level 9, format "□ A", right associativity).
#[local] Notation "◇ A" := (DiamondT Tri id A) (at level 9, format "◇ A", right associativity).
#[local] Notation "? A" := (Option A) (at level 9, format "? A", right associativity).
#[local] Notation "◆ A" := (DiamondT Tri Option A) (at level 9, format "◆ A", right associativity).
#[local] Notation "A * B" := (Prod A B).
#[local] Notation "s [ ζ ]" :=
  (persist _ s _ ζ)
    (at level 8, left associativity,
      format "s [ ζ ]").

(* Notation "ζ1 ≽ ζ2" := (Subgeq ζ1 ζ2) (at level 80). *)
(* Notation "ζ1 ≲ ζ2" := (Subleq ζ1 ζ2) (at level 80). *)
(* Notation "ζ1 ≼ ζ2" := (Trileq ζ1 ζ2) (at level 80). *)

Module Import SubstitutionPredicates.

  Definition SubPred : TYPE :=
    fun w => forall w', w ⊒ˢ w' -> Prop.
  (* □PROP. *)

  Import (hints) Sub.
  Section Instances.

    Context {w : World}.

    Definition iff (P Q : SubPred w) : Prop :=
      forall Δ ζ, P Δ ζ <-> Q Δ ζ.
    Infix "<->" := iff.

    Instance iff_refl : Reflexive iff.
    Proof. unfold Reflexive, iff. intros. reflexivity. Qed.
    Instance iff_sym : Symmetric iff.
    Proof. unfold Symmetric, iff. intros. now symmetry. Qed.
    Instance iff_trans : Transitive iff.
    Proof. unfold Transitive, iff. intros. now transitivity (y Δ ζ). Qed.

    Instance iff_equiv : Equivalence iff.
    Proof. constructor; auto with typeclass_instances. Qed.

    Definition and (P Q : SubPred w) : SubPred w :=
      fun _ ζ => P _ ζ /\ Q _ ζ.
    Instance proper_and : Proper (iff ==> iff ==> iff) and.
    Proof. firstorder. Qed.

    Definition impl (P Q : SubPred w) : SubPred w :=
      (fun w' ζ => P w' ζ -> Q w' ζ)%type.

    Definition nothing (P : SubPred w) : Prop :=
      forall w' ζ, P w' ζ -> False.
    Instance proper_nothing : Proper (iff ==> Logic.iff) nothing.
    Proof. intros ? ? ?. do 2 (apply all_iff_morphism; intros ?). intuition. Qed.

    Definition max (P : SubPred w) : SubPred w :=
      and P (fun w1 ζ1 => forall w2 ζ2, P w2 ζ2 -> ζ1 ≽ˢ ζ2).
    Instance proper_max : Proper (iff ==> iff) max.
    Proof. firstorder. Qed.
    Instance proper_max' : Proper (iff ==> forall_relation (fun w => eq ==> Basics.flip Basics.impl)) max.
    Proof. repeat intro; subst; firstorder. Qed.

  End Instances.
  #[export] Existing Instance iff_refl.
  #[export] Existing Instance iff_sym.
  #[export] Existing Instance iff_trans.
  #[export] Existing Instance iff_equiv.
  #[export] Existing Instance proper_and.
  #[export] Existing Instance proper_nothing.
  #[export] Existing Instance proper_max.
  #[export] Existing Instance proper_max'.

  Notation "P <-> Q" := (iff P Q).

  Definition unifies : ⊢ Ty -> Ty -> SubPred :=
    fun w s t w1 (ζ1 : w ⊒ˢ w1) => s[ζ1] = t[ζ1].

  Definition unifiesX : ⊢ Ty -> Ty -> SubPred :=
    fun w0 s t =>
      match s , t with
      | Ty_hole xIn as s , t               => unifies s t
      | s               , Ty_hole yIn as t => unifies s t
      | Ty_bool          , Ty_bool          => fun _ _ => True
      | Ty_func s1 s2    , Ty_func t1 t2    => and (unifies s1 t1) (unifies s2 t2)
      | s               , t               => fun _ _ => False
      end.

  Definition unifiesY : ⊢ Ty -> Ty -> SubPred :=
    fun w0 =>
      fix ufs s t {struct s} :=
      match s , t with
      | Ty_hole xIn as s , t               => unifies s t
      | s               , Ty_hole yIn as t => unifies s t
      | Ty_bool          , Ty_bool          => fun _ _ => True
      | Ty_func s1 s2    , Ty_func t1 t2    => and (ufs s1 t1) (ufs s2 t2)
      | _               , _               => fun _ _ => False
      end.

  Lemma unifies_sym {w} (s t : Ty w) : iff (unifies s t) (unifies t s).
  Proof. now unfold iff, unifies. Qed.

  Lemma unifiesX_equiv {w} (s t : Ty w) : iff (unifies s t) (unifiesX s t).
  Proof.
    destruct s; cbn; [| |reflexivity]; try now destruct t.
    destruct t; auto.
    - split; intuition discriminate.
    - unfold iff, unifies, and; cbn. intuition congruence.
    - reflexivity.
  Qed.

  Lemma unifiesY_equiv {w} (s t : Ty w) : iff (unifies s t) (unifiesY s t).
  Proof.
    revert t; induction s; intros t; destruct t; cbn in *;
      try reflexivity;
      try (unfold iff, unifies; cbn; intuition congruence).
    - rewrite <- IHs1, <- IHs2.
      unfold iff, unifies, and; cbn.
      intuition congruence.
  Qed.

  Definition DClosed {w} (P : SubPred w) : Prop :=
    forall w1 w2 (ζ1 : w ⊒ˢ w1) (ζ2 : w ⊒ˢ w2),
      ζ1 ≽ˢ ζ2 -> P w1 ζ1 -> P w2 ζ2.

  Lemma dclosed_unifies {w} (s t : Ty w) : DClosed (unifies s t).
  Proof.
    unfold DClosed, unifies.
    intros ? ? ? ? [? ->] ?.
    rewrite ?persist_trans.
    now f_equal.
  Qed.

  Definition extend {w1 w2} (P : SubPred w1) (ζ1 : w1 ⊒ˢ w2) : SubPred w2 :=
    fun Δ ζ2 => P Δ (ζ1 ⊙ ζ2).

  Lemma extend_id {w0} (P : SubPred w0) :
    iff (extend P refl) P.
  Proof.
    unfold iff, extend. intros.
    now rewrite trans_refl_l.
  Qed.

  Lemma extend_and {w0 w1} (P Q : SubPred w0) (ζ1 : w0 ⊒ˢ w1) :
    iff (extend (and P Q) ζ1) (and (extend P ζ1) (extend Q ζ1)).
  Proof. reflexivity. Qed.

  Lemma extend_unifies {w0 w1} (s t : Ty w0) (ζ : w0 ⊒ˢ w1) :
    iff (unifies s[ζ] t[ζ]) (extend (unifies s t) ζ).
  Proof.
    unfold iff, extend, unifies. intros.
    now rewrite ?persist_trans.
  Qed.

  Lemma optimists {w0 w1 w2 w3} (P Q : SubPred w0) (ζ1 : w0 ⊒ˢ w1) (ζ2 : w1 ⊒ˢ w2) (ζ3 : w2 ⊒ˢ w3) :
    DClosed P ->
    max (extend P ζ1) ζ2 ->
    max (extend Q (ζ1 ⊙ ζ2)) ζ3 ->
    max (extend (and P Q) ζ1) (ζ2 ⊙ ζ3).
  Proof.
    unfold DClosed, extend.
    intros dcp [p12 pmax] [q123 qmax].
    split.
    split.
    - revert p12. apply dcp.
      apply Sub.geq_precom.
      apply Sub.geq_extend.
    - revert q123. now rewrite trans_assoc.
    - intros ? f [H1 H2].
      apply pmax in H1.
      destruct H1 as [g ?].
      subst f.
      apply Sub.geq_precom.
      apply qmax.
      now rewrite trans_assoc.
  Qed.

  Lemma optimists_unifies {w w1 w2 w3} {s1 s2 t1 t2 : Ty w}
    (ζ1 : w ⊒ˢ w1) (ζ2 : w1 ⊒ˢ w2) (ζ3 : w2 ⊒ˢ w3) :
    max (unifies s1[ζ1] t1[ζ1]) ζ2 ->
    max (unifies s2[ζ1 ⊙ ζ2] t2[ζ1 ⊙ ζ2]) ζ3 ->
    max (and (unifies s1[ζ1] t1[ζ1]) (unifies s2[ζ1] t2[ζ1])) (ζ2 ⊙ ζ3).
  Proof.
    unfold max, and, unifies. rewrite ?persist_trans.
    intros [p12 pmax] [q123 qmax]. split. split; congruence.
    intros w4 ζ4 [H1 H2].
    apply pmax in H1. destruct H1 as [ζ24 ->]. rewrite ?persist_trans in H2.
    apply qmax in H2. destruct H2 as [ζ34 ->].
    apply Sub.geq_precom.
    apply Sub.geq_extend.
  Qed.

  Lemma trivialproblem {w} (t : Ty w) :
    max (unifies t t) refl.
  Proof.
    unfold max. split.
    - reflexivity.
    - intros ? ζ ?. exists ζ.
      now rewrite trans_refl_l.
  Qed.

  Lemma varelim {w x} (xIn : x ∈ w) (t : Ty (w - x)) :
    max (unifies (Ty_hole xIn) (thin xIn t)) (thick (R := Sub) x t).
  Proof.
    rewrite Sub.subst_thin.
    split.
    - unfold unifies. cbn.
      rewrite Sub.lk_thick.
      unfold thickIn.
      rewrite ctx.occurs_check_view_refl.
      rewrite <- persist_trans.
      rewrite Sub.comp_thin_thick.
      rewrite persist_refl.
      reflexivity.
    - unfold unifies, Sub.geq. cbn. intros * Heq.
      exists (Sub.thin xIn ⊙ ζ2).
      apply env.lookup_extensional. intros y yIn. Sub.foldlk.
      rewrite ?Sub.lk_trans, Sub.lk_thick, persist_trans.
      unfold thickIn.
      destruct (ctx.occurs_check_view xIn yIn); cbn.
      + apply Heq.
      + now rewrite Sub.lk_thin.
  Qed.

  Lemma nothing_unifies_occurs_strictly {w x} (xIn : x ∈ w) (t : Ty w) :
    Ty_subterm (Ty_hole xIn) t ->
    nothing (unifies (Ty_hole xIn) t).
  Proof.
    unfold nothing, unifies; intros.
    apply Ty_no_cycle with t[ζ].
    rewrite <- H0 at 1.
    now apply Sub.Ty_subterm_subst.
  Qed.

End SubstitutionPredicates.
Export SubstitutionPredicates (SubPred).

Module NoGhostState.
  Import (hints) Tri.

  Definition wp {A} : ⊢ ◆A -> □(A -> PROP) -> PROP :=
    fun w0 a0 POST => option.wp (fun '(w1; (ζ1 , a1)) => POST w1 ζ1 a1) a0.

  Definition wlp {A} : ⊢ ◆A -> □(A -> PROP) -> PROP :=
    fun w0 a0 POST => option.wlp (fun '(w1; (ζ1 , a1)) => POST w1 ζ1 a1) a0.

  Definition spec {A} : ⊢ ◆A -> □(A -> PROP) -> PROP -> PROP :=
    fun w0 a0 SPOST NPOST => option.spec (fun '(w1; (ζ1 , a1)) => SPOST w1 ζ1 a1) NPOST a0.

  Lemma wp_η {A w} (a : A w) (POST : □(A -> PROP) w) :
    wp (η a) POST <-> T POST a.
  Proof. unfold wp, η. now option.tactics.mixin. Qed.

  Lemma wp_μ {A B w} (a : ◆A w) (f : □(A -> ◆B) w) (POST : □(B -> PROP) w) :
    wp (bind a f) POST <-> wp a (fun _ ζ1 a1 => wp (f _ ζ1 a1) (_4 POST ζ1)).
  Proof.
    unfold wp, bind, acc, Diamond.
    now repeat
      (rewrite ?option.wp_bind, ?option.wp_map;
       repeat option.tactics.mixin;
       intros; try destruct_conjs).
  Qed.

  Lemma wlp_η {A w} (a : A w) (POST : □(A -> PROP) w) :
    wlp (η a) POST <-> T POST a.
  Proof. unfold wlp, η. now option.tactics.mixin. Qed.

  Lemma wlp_μ {A B w} (a : ◆A w) (f : □(A -> ◆B) w) (POST : □(B -> PROP) w) :
    wlp (bind a f) POST <-> wlp a (fun _ ζ1 a1 => wlp (f _ ζ1 a1) (_4 POST ζ1)).
  Proof.
    unfold wlp, bind, acc, Diamond.
    now repeat
      (rewrite ?option.wlp_bind, ?option.wlp_map;
       repeat option.tactics.mixin;
       intros; try destruct_conjs).
  Qed.

  Lemma spec_η {A w} (a : A w) (SPOST : □(A -> PROP) w) (NPOST : PROP w) :
    spec (η a) SPOST NPOST <-> T SPOST a.
  Proof.
    unfold spec, η. now option.tactics.mixin.
  Qed.

  Lemma spec_μ {A B w} (a : ◆A w) (f : □(A -> ◆B) w) (SPOST : □(B -> PROP) w) (NPOST : PROP w) :
    spec (bind a f) SPOST NPOST <->
    spec a (fun _ ζ1 a1 => spec (f _ ζ1 a1) (_4 SPOST ζ1) NPOST) NPOST.
  Proof.
    unfold spec, bind, acc, Diamond.
    repeat
      (rewrite ?option.spec_bind, ?option.spec_map;
       repeat option.tactics.mixin;
       intros; try destruct_conjs); try reflexivity.
  Qed.

End NoGhostState.
Import NoGhostState.

Module Correctness.
  Import (hints) Sub Tri.

  Definition UnifierSpec : ⊢ Unifier -> PROP :=
    fun w u =>
      forall t1 t2,
        let P := unifies t1 t2 in
        spec
          (u t1 t2)
          (fun w2 ζ2 _ => max P (Sub.triangular ζ2))
          (nothing P).

  Definition BoxUnifierSpec : ⊢ BoxUnifier -> PROP :=
    fun w bu =>
      forall t1 t2 w1 (ζ1 : w ⊒⁻ w1),
        let P := unifies t1[ζ1] t2[ζ1] in
        spec
          (bu t1 t2 w1 ζ1)
          (fun w2 ζ2 _ => max P (Sub.triangular ζ2))
          (nothing P).

  Lemma flex_sound {w y} (t : Ty w) (yIn : y ∈ w) :
    wlp (flex t yIn) (fun _ ζ1 _ => unifies t (Ty_hole yIn) (Sub.triangular ζ1)).
  Proof.
    unfold unifies, flex, wlp.
    destruct (varview t).
    - destruct (ctx.occurs_check_view yIn xIn).
      + constructor. reflexivity.
      + constructor. cbn. Sub.foldlk.
        rewrite trans_refl_r.
        rewrite !Sub.lk_thick. unfold thickIn.
        now rewrite !ctx.occurs_check_view_refl, !ctx.occurs_check_view_thin.
    - apply option.wlp_map.
      generalize (occurs_check_sound t yIn).
      apply option.wlp_monotonic.
      intros t' ->. cbn. Sub.foldlk.
      rewrite trans_refl_r.
      rewrite Sub.subst_thin.
      rewrite <- persist_trans.
      rewrite Sub.comp_thin_thick.
      rewrite persist_refl.
      rewrite Sub.lk_thick.
      unfold thickIn.
      now rewrite ctx.occurs_check_view_refl.
  Qed.

  Lemma flex_complete {w0 w1 y} (ζ1 : w0 ⊒ˢ w1) (t : Ty w0) (yIn : y ∈ w0) :
    unifies t (Ty_hole yIn) ζ1 ->
    wp (flex t yIn) (fun mgw mgζ _ => Sub.triangular mgζ ≽ˢ ζ1).
  Proof.
    intros. unfold flex.
    destruct (varview t).
    - destruct (ctx.occurs_check_view yIn xIn).
      + constructor. apply Sub.geq_max.
      + constructor; cbn.
        rewrite trans_refl_r.
        apply (@varelim _ _ yIn).
        now symmetry.
    - unfold wp. apply option.wp_map.
      destruct (occurs_check_spec yIn t).
      + constructor. cbn. subst.
        rewrite trans_refl_r.
        apply varelim. now symmetry.
      + exfalso. destruct H1.
        * specialize (H0 _ yIn). contradiction.
        * apply nothing_unifies_occurs_strictly in H1.
          now apply (H1 _ ζ1).
  Qed.

  Lemma flex_spec {w x} (xIn : x ∈ w) (t : Ty w) :
    let P := unifies (Ty_hole xIn) t in
    spec
      (flex t xIn)
      (fun w' ζ' _ => max P (Sub.triangular ζ'))
      (nothing P).
  Proof.
    unfold flex.
    destruct (varview t).
    - destruct (ctx.occurs_check_view xIn xIn0); subst.
      + constructor. apply trivialproblem.
      + constructor. cbn.
        rewrite trans_refl_r.
        change (Ty_hole (ctx.in_thin xIn yIn)) with (thin xIn (Ty_hole yIn)).
        apply varelim.
    - apply option.spec_map.
      generalize (occurs_check_spec xIn t).
      apply option.spec_monotonic.
      + intros t' ->. cbn.
        rewrite trans_refl_r.
        apply varelim.
      + specialize (H _ xIn).
        intros []. contradiction.
        now apply nothing_unifies_occurs_strictly.
  Qed.

  Section BoxedProofs.

    Context [w] (lmgu : ▷BoxUnifier w).
    Context (lmgu_spec : forall x (xIn : x ∈ w),
                  BoxUnifierSpec (lmgu xIn)).

    Lemma boxflex_spec {x} (xIn : x ∈ w) (t : Ty w) (w1 : World) (ζ1 : w ⊒⁻ w1) :
      let P := unifies (Ty_hole xIn)[ζ1] t[ζ1] in
      spec (boxflex lmgu t xIn ζ1) (fun w2 ζ2 _ => max P (Sub.triangular ζ2)) (nothing P).
    Proof.
      unfold boxflex, Tri.box_intro_split.
      destruct ζ1; cbn - [persist]; folddefs.
      - rewrite !persist_refl. apply flex_spec.
      - rewrite !persist_trans. apply lmgu_spec.
    Qed.

      (* Lemma boxmgu_correct (t1 t2 : Ty w) : *)
      (*   forall {w1} (ζ1 : w ⊒⁻ w1) {w2} (ζ2 : w1 ⊒⁻ w2), *)
      (*     mg (boxmgu t1 t2 ζ1) (cmgu t1 t2 (ζ1 ⊙ ζ2)) ζ2. *)
      (* Proof. *)
      (*   pattern (boxmgu t1 t2). apply boxmgu_elim; clear t1 t2. *)
      (*   - admit. *)
      (*   - admit. *)
      (*   - intros. exists ζ2. cbn - [Sub.comp]. now rewrite Sub.comp_id_left. *)
      (*   - intros. constructor. *)
      (*   - intros. constructor. *)
      (*   - intros * IH1 IH2 *. cbn. *)
      (*     (* apply (mg_bind (boxmgu s1 t1 ζ1) _ (cmgu s1 t1 (ζ1 ⊙ ζ2))); auto. *) *)
      (* Admitted. *)

      (* Lemma boxmgu_spec : BoxUnifierSpec boxmgu. *)
      (* Proof. *)
      (*   intros s t. pattern (boxmgu s t). *)
      (*   apply boxmgu_elim; clear s t. *)
      (*   - cbn. intros. apply boxflex_spec. *)
      (*   - cbn. intros x xIn t w1 ζ1. *)
      (*     generalize (boxflex_spec xIn t ζ1). cbn. *)
      (*     apply option.spec_monotonic. *)
      (*     + intros [w2 [ζ2 []]] H. *)
      (*       now rewrite unifies_sym. *)
      (*     + intros H. *)
      (*       now rewrite unifies_sym. *)
      (*   - constructor. apply trivialproblem. *)
      (*   - constructor. discriminate. *)
      (*   - constructor. discriminate. *)
      (*   - cbn. intros. *)
      (*     rewrite spec_μ. *)
      (*     generalize (H w1 ζ1). clear H. *)
      (*     apply option.spec_monotonic. *)
      (*     intros [w2 [ζ2 _]] ?. *)
      (*     rewrite spec_μ. *)
      (*     generalize (H0 w2 (Tri.trans ζ1 ζ2)). clear H0. *)
      (*     apply option.spec_monotonic. *)
      (*     intros [w3 [ζ3 _]] ?. *)
      (*     constructor. unfold four. *)
      (*     + rewrite Tri.trans_refl, unifiesX_equiv; cbn. *)
      (*       rewrite Sub.triangular_trans. *)
      (*       rewrite Sub.triangular_trans in H0. *)
      (*       now apply optimists_unifies. *)
      (*     + admit. *)
      (*     + admit. *)
      (* Admitted. *)

      Lemma boxmgu_sound (t1 t2 : Ty w) :
        forall {w1} (ζ1 : w ⊒⁻ w1),
          wlp
            (boxmgu lmgu t1 t2 ζ1)
            (fun w2 ζ2 _ => unifies t1[ζ1] t2[ζ1] (Sub.triangular ζ2)).
      Proof.
        pattern (boxmgu lmgu t1 t2).
        apply boxmgu_elim; clear t1 t2; cbn; intros; try (now constructor).
        - destruct (boxflex_spec xIn t ζ1); constructor.
          destruct a as [w2 [ζ2 []]]. apply H.
        - destruct (boxflex_spec xIn t ζ1); constructor.
          destruct a as [w2 [ζ2 []]]. apply unifies_sym. apply H.
        - rewrite wlp_μ. generalize (H _ ζ1). clear H.
          apply option.wlp_monotonic. intros [w2 [ζ2 _]] ?.
          rewrite wlp_μ. generalize (H0 _ (ζ1 ⊙⁻ ζ2)).
          apply option.wlp_monotonic. intros [w3 [ζ3 _]] ?.
          constructor. unfold _4.
          rewrite trans_refl_r.
          rewrite Sub.triangular_trans.
          rewrite !Tri.persist_func.
          apply unifiesX_equiv. cbn.
          split.
          + revert H. apply dclosed_unifies. apply Sub.geq_extend.
          + revert H1. unfold unifies.
            now rewrite ?persist_trans, ?Sub.persist_triangular.
      Qed.

      Lemma boxmgu_complete (t1 t2 : Ty w) :
        forall {w0} (ζ0 : w ⊒⁻ w0) [w1] (ζ1 : w0 ⊒ˢ w1),
          unifies t1[ζ0] t2[ζ0] ζ1 ->
          wp (boxmgu lmgu t1 t2 ζ0) (fun mgw mgζ _ => Sub.triangular mgζ ≽ˢ ζ1).
      Proof.
        pattern (boxmgu lmgu t1 t2).
        apply boxmgu_elim; clear t1 t2;
          cbn; intros; try (now constructor);
          rewrite ?Tri.persist_bool, ?Tri.persist_func in *;
          try discriminate.
        - destruct (boxflex_spec xIn t ζ0).
          + constructor. destruct a as [w2 [ζ2 []]]. now apply H0.
          + now apply H0 in H.
        - destruct (boxflex_spec xIn t ζ0).
          + constructor. destruct a as [w2 [ζ2 []]]. now apply H0.
          + now apply unifies_sym, H0 in H.
        - constructor. apply Sub.geq_max.
        - apply unifiesX_equiv in H1. destruct H1 as [HU1 HU2].
          rewrite wp_μ. generalize (H _ ζ0 _ ζ1 HU1). clear H.
          apply option.wp_monotonic. intros [mgw1 [mgζ1 _]] [ζ1' ->].
          assert (unifies s2[ζ0 ⊙⁻ mgζ1] t2[ζ0 ⊙⁻ mgζ1] ζ1') as HU2'.
          { revert HU2. unfold unifies.
            now rewrite ?persist_trans, ?Sub.persist_triangular.
          }
          rewrite wp_μ. generalize (H0 _ (ζ0 ⊙⁻ mgζ1) _ ζ1' HU2').
          apply option.wp_monotonic. intros [mgw2 [mgζ2 _]] [ζ2' ->].
          constructor. unfold _4.
          rewrite ?Sub.triangular_trans.
          apply Sub.geq_precom.
          apply Sub.geq_precom.
          apply Sub.geq_max.
      Qed.

      Lemma boxmgu_spec' : BoxUnifierSpec (boxmgu lmgu).
      Proof.
        unfold BoxUnifierSpec. intros *.
        pose proof (boxmgu_complete t1 t2 ζ1) as Hcompl.
        destruct (boxmgu_sound t1 t2 ζ1); constructor.
        - destruct a as [w2 [ζ2 []]]. split; auto.
          intros w3 ζ3 Hζ3. specialize (Hcompl w3 ζ3 Hζ3). revert Hcompl.
          unfold wp. now rewrite option.wp_match.
        - intros w3 ζ3 Hζ3. specialize (Hcompl w3 ζ3 Hζ3). revert Hcompl.
          unfold wp. now rewrite option.wp_match.
      Qed.

  End BoxedProofs.

  Lemma bmgu_spec w : @BoxUnifierSpec w (@bmgu w).
  Proof.
    pattern (@bmgu w). revert w. apply Löb_elim.
    intros w IH. now apply boxmgu_spec'.
  Qed.

  Definition mgu_spec w : UnifierSpec (@mgu w).
  Proof.
    unfold UnifierSpec, mgu. intros t1 t2.
    generalize (bmgu_spec t1 t2 refl).
    now rewrite !persist_refl.
  Qed.

  Definition spec' {A} : ⊢ ◆A -> □(Option A -> PROP) -> PROP.
    refine (fun w0 a0 POST => _).
    destruct a0 as [[w1 [ζ1 a]]|].
    cbv. apply (POST w1 ζ1 (Some a)).
    apply (T POST None).
  Defined.

  Definition Wpure : TYPE -> TYPE :=
    fun A => □(A -> PROP) -> PROP.
  Definition DiamondT (M : TYPE -> TYPE) : TYPE -> TYPE :=
    fun A => M (fun w0 => {w1 : World & ((w0 ⊒⁻ w1) * A w1)}%type).
  Definition OptionT (M : TYPE -> TYPE) : TYPE -> TYPE :=
    fun A => M (Option A).

  Definition W := DiamondT (OptionT Wpure).

  Definition flexspecw : ⊢ Ty -> ∀ x, ctx.In x -> W Unit.
  Proof.
    cbv [Impl Valid Box Forall PROP W OptionT DiamondT Wpure Option].
    intros w0 t x xIn POST.
    refine (exists w1 : World, exists ζ1 : w0 ⊒⁻ w1, POST w1 ζ1 _).
    destruct (eq_dec (Ty_hole xIn)[Sub.triangular ζ1] t[Sub.triangular ζ1]).
    apply Some. exists w1. split. apply refl. apply tt.
    apply None.
  Defined.

  Definition flexspec : ⊢ Ty -> ∀ x, ctx.In x -> □(Option Unit -> PROP) -> PROP.
  Proof.
    cbv [Impl Valid Box Forall PROP].
    intros w0 t x xIn POST.
    refine (exists w1 : World, exists ζ1 : w0 ⊒⁻ w1, POST w1 ζ1 _).
    destruct (eq_dec (Ty_hole xIn)[Sub.triangular ζ1] t[Sub.triangular ζ1]).
    apply (Some tt).
    apply None.
  Defined.

  Definition order {Unit} : ⊢ (□(Option Unit -> PROP) -> PROP) -> (□(Option Unit -> PROP) -> PROP) -> PROP :=
    fun w0 PT QT =>
      forall (P Q : □(Option Unit -> PROP) w0),
        (forall w1 (ζ1 : w0 ⊒⁻ w1) (x : Option Unit w1),
            P w1 ζ1 x -> Q w1 ζ1 x) ->
        PT P -> QT Q.

  Lemma flexverify {w} (t : Ty w) {x} (xIn : x ∈ w) :
    order (spec' (flex t xIn)) (flexspec t xIn).
  Proof.
    unfold flex. destruct (varview t) as [y yIn|].
    - destruct (ctx.occurs_check_view xIn yIn); unfold order, spec', flexspec, η;
        cbn - [eq_dec]; intros P Q PQ HP.
      + exists w. exists refl. rewrite eq_dec_refl. auto.
      + exists (w - x). exists (thick (R := Tri) x (Ty_hole yIn)).
  Admitted.

  Definition cflex : ⊢ Ty -> Ty -> Option Unit :=
    fun w s t => if eq_dec s t then Some tt else None.

  Definition mg : ⊢ ◆Unit -> □(Option Unit -> PROP) :=
    fun w0 d w1 ζ1 o =>
      match o , d with
      | Some _ , Some (existT _ mgw (mgζ , _)) => Sub.triangular mgζ ≽ˢ Sub.triangular ζ1
      | None   , _                             => True
      | Some _ , None                          => False
      end.

  Module Related.
    Definition DUM {w0 w1} (ζ1 : w0 ⊒⁻ w1) (spec : Option Unit w1) : Type :=
      { m : ◆Unit w0 | mg m ζ1 spec }.

    Definition dret {w0 w1} (ζ1 : w0 ⊒⁻ w1) (a : Unit w0) : DUM ζ1 (Some a) :=
      exist _ (Some (w0; (Tri.refl, a))) (Sub.geq_max (Sub.triangular ζ1)).

    Definition flexspec {w0} (t : Ty w0) {x} (xIn : x ∈ w0) {w1} (ζ1 : w0 ⊒⁻ w1) : Option Unit w1 :=
      if eq_dec (Ty_hole xIn)[Sub.triangular ζ1] t[Sub.triangular ζ1] then Some tt else None.

    Program Definition dflex {w0} (t : Ty w0) {x} (xIn : x ∈ w0) {w1} (ζ1 : w0 ⊒⁻ w1) : DUM ζ1 (flexspec t xIn ζ1) :=
        match varview t with
        | is_var yIn =>
            match ctx.occurs_check_view xIn yIn with
            | ctx.Same _      => η tt
            | ctx.Diff _ yIn' => Some (sooner2diamond (_; (xIn; (Ty_hole yIn', tt))))
            end
        | not_var _ =>
            option_map
              (fun t' => sooner2diamond (x; (xIn; (t', tt))))
              (occurs_check t xIn)
        end.
    Admit Obligations.

  End Related.

  (* Module DijkstraM. *)
  (*   Definition obs {w} (m : ◆Unit w) {w2} (ζ2 : w ⊒ˢ w2) : Option Unit w2 := *)
  (*     match m with *)
  (*     | Some (x; (ζ1, a)) => if ζ1 ≽? ζ2 then Some a else None *)
  (*     | None              => None *)
  (*     end. *)

  (*   Definition DUM {w0 w1} (ζ1 : w0 ⊒⁻ w1) (spec : Option Unit w1) : Type := *)
  (*     { m : ◆Unit w0 | obs m ζ1 = spec }. *)

  (*   Definition dret {w0 w1} (ζ1 : w0 ⊒⁻ w1) (a : Unit w0) : DUM ζ1 (Some a) := *)
  (*     exist _ (Some (w0; (Tri.refl, a))) eq_refl. *)
  (* End DijkstraM. *)

  (* Lemma mg_bind {w0} (da : ◆Unit w0) (dk : □(Unit -> ◆Unit) w0) *)
  (*   {w1} (ζ1 : w0 ⊒⁻ w1) (oa : Option Unit w1) (ok : Unit w1 -> Option Unit w1) : *)
  (*   mg da ζ1 oa -> *)
  (*   (forall {w2} (ζ2 : w ⊒⁻ w2), ζ2 ≽ˢ ζ1 -> mg (dk w1 ζ1 tt) (ok tt) ζ2) -> *)
  (*   mg (bind da dk) ζ2 (option.bind oa ok). *)
  (* Proof. *)
  (*   unfold bind, option.bind, mg at 1. intros mga mgk. *)
  (*   destruct da as [[? []]|], oa; try easy. *)
  (*   destruct u, u0. now apply mgk. *)
  (* Qed. *)

  (* Lemma mg_acc {w w1} (ζ1 : w ⊒⁻ w1) (d : ◆Unit w1) (o : Option Unit w) {w2} (ζ2 : w ⊒⁻ w2) : *)
  (*   (* mg da oa ζ2 -> *) *)
  (*   (* (forall {w1} (ζ1 : w ⊒⁻ w1), ζ2 ≲ ζ1 -> mg (acc ζ1 (dk w1 ζ1 tt)) (ok tt) ζ2) -> *) *)
  (*   mg (acc ζ1 d) o ζ2. *)
  (* Proof. *)
  (*   destruct o; cbn; auto. *)
  (*   destruct d as [[? []]|]; cbn. admit. ; try easy. *)
  (*   destruct u, u0. now apply mgk. *)
  (* Qed. *)

  Lemma flexcorrect {w} (t : Ty w) {x} (xIn : x ∈ w) {w2} (ζ2 : w ⊒⁻ w2) :
    mg (flex t xIn) ζ2 (cflex (Ty_hole xIn)[Sub.triangular ζ2] t[Sub.triangular ζ2]).
  Proof.
    unfold cflex, mg. destruct (eq_dec (Ty_hole xIn)[Sub.triangular ζ2] t[Sub.triangular ζ2]).
    - unfold flex. destruct (varview t) as [y yIn|].
      + destruct (ctx.occurs_check_view xIn yIn); cbn.
        * apply Sub.geq_max.
        * rewrite trans_refl_r. now apply varelim.
      + destruct (occurs_check_spec xIn t) as [|[]]; cbn.
        * rewrite trans_refl_r. subst. now apply varelim.
        * now apply H in H0.
        * apply nothing_unifies_occurs_strictly in H0.
          apply (H0 _ _ e).
    - destruct (flex t xIn) as [[? [? []]]|]; auto.
  Qed.

  Definition CMGU : TYPE := Ty -> Ty -> □(Option Unit).

  Section CMgu.
    Import option.notations.
    (* Context [w] (lcmgu : ▻CMGU w). *)

    Definition cmgu : ⊢ CMGU :=
      fun w => fix cmgu s t :=
        match s , t with
        | Ty_hole xIn as s , t               => fun _ ζ => cflex s[Sub.triangular ζ] t[Sub.triangular ζ]
        | s               , Ty_hole yIn as t => fun _ ζ => cflex s[Sub.triangular ζ] t[Sub.triangular ζ]
        | Ty_bool          , Ty_bool          => fun _ _ => Some tt
        | Ty_func s1 s2    , Ty_func t1 t2    => fun _ ζ => 'tt <- cmgu s1 t1 _ ζ ;; 'tt <- cmgu s2 t2 _ ζ ;; Some tt
        | _               , _               => fun _ _ => None
        end.
  End CMgu.

  (* Definition cmgu : ⊢ CMGU. *)
  (*   intros w. apply Löb. unfold Valid, Impl. intros w1. Check gcmgu. *)
  (*   fun w s t => T (@Löb _ @gcmgu w s t). *)

End Correctness.