{-# LANGUAGE OverloadedStrings #-}

{-| The public data structures used by the Karps compiler.
-}
module Spark.Core.Internal.BrainStructures where

{-| The configuration of the compiler. All these options change the
output reported by the compiler. They are fixed at compile time or by the
Haskell client currently.
-}
data CompilerConf = CompilerConf {
  {-| If enabled, attempts to prune the computation graph as much as possible.

  This option is useful in interactive sessions when long chains of computations
  are extracted. This forces the execution of only the missing parts.
  The algorithm is experimental, so disabling it is a safe option.

  Disabled by default.
  -}
  ccUseNodePruning :: !Bool
} deriving (Eq, Show)
