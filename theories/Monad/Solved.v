(******************************************************************************)
(* Copyright (c) 2023 Denis Carnier, Steven Keuchel                           *)
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

From iris Require Import proofmode.tactics.
From Em Require Import Monad.Interface Triangular Unification.

Import Pred Pred.Acc Pred.proofmode world.notations.

Section WithSub.

  Context {Θ} {reflΘ : Refl Θ} {transΘ : Trans Θ}
    {hmapΘ : HMap Tri Θ} {stepΘ : Step Θ}.

  #[export] Instance tcm_solved : TypeCheckM (Solved Θ) :=
    {| assert w τ1 τ2 := mgu τ1 τ2;
       pick w := let α := world.fresh w in
                 Some (existT (w ▻ α) (step, ṫy.var world.in_zero));
    |}.

  Context {reflTransΘ : ReflTrans Θ} {lkreflΘ : LkRefl Θ} {lkTransΘ : LkTrans Θ}
    {lkhmapΘ : LkHMap Tri Θ} {lkStepθ : LkStep Θ}.

  #[export] Instance tcmlogic_solved : TypeCheckLogicM Θ (Solved Θ).
  Proof.
    constructor; intros; predsimpl.
    - destruct m as [(w1 & θ1 & a1)|]; predsimpl.
      destruct f as [(w2 & θ2 & b2)|]; predsimpl.
    - rewrite <- mgu_correct. destruct mgu as [(w1 & θ1 & [])|]; predsimpl.
      iIntros "[Hwp #HQ]". iApply (Acc.wp_mono with "[] Hwp").
      iIntros "!> _". iMod "HQ". now rewrite trans_refl_r.
    - rewrite <- (intro_wp_step τ). iIntros "#HQ !> #Heq". iMod "HQ".
      rewrite trans_refl_r. iApply "HQ". now iModIntro.
    - destruct m as [(w1 & θ1 & a1)|]; predsimpl.
      iIntros "PQ". iApply Acc.wp_mono. iModIntro.
      iMod "PQ". now rewrite trans_refl_r.
    - destruct m as [(w1 & θ1 & a1)|]; predsimpl.
      destruct f as [(w2 & θ2 & b2)|]; predsimpl.
    - rewrite <- mgu_correct. destruct mgu as [(w1 & θ1 & [])|]; predsimpl.
      rewrite Acc.wp_impl. predsimpl. iIntros "HQ !>".
      rewrite persist_update. iMod "HQ". now rewrite trans_refl_r.
    - iIntros "HQ !>". iMod "HQ". rewrite trans_refl_r. iApply "HQ".
    - destruct m as [(w1 & θ1 & a1)|]; predsimpl.
      iIntros "PQ". iApply Acc.wlp_mono. iModIntro.
      iMod "PQ". now rewrite trans_refl_r.
    - destruct m as [(w1 & θ1 & a1)|]; predsimpl.
      rewrite Acc.wp_impl. predsimpl.
  Qed.

End WithSub.