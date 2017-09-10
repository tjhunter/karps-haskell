{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}

{-| The public data structures used by the Karps compiler.
-}
module Spark.Core.Internal.BrainStructures where

import Data.Map.Strict(Map)
import Data.Text(Text)
import Data.Default

import Spark.Core.Internal.Utilities
import Spark.Core.Internal.ProtoUtils
import Spark.Core.Internal.ComputeDag(ComputeDag)
import Spark.Core.Internal.DatasetStructures(StructureEdge, OperatorNode)
import Spark.Core.StructuresInternal(NodeId, ComputationID, NodePath)
import Spark.Core.Try(NodeError)
import qualified Proto.Karps.Proto.Computation as PC
import qualified Proto.Karps.Proto.ApiInternal as PAI

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

{-| The notion of a session in Karps.

A session is a coherent set of builders, computed (cached) nodes, associated to
a computation backend that performs the operations.

While the compiler does not require any knowledge of a session, it can reuse
data that was computed in other sessions if requested, hence the definition
here.
-}
data LocalSessionId = LocalSessionId {
  unLocalSession :: !Text
} deriving (Eq, Show)


{-| A path that is unique across all the application. -}
data GlobalPath = GlobalPath {
  gpSessionId :: !LocalSessionId,
  gpComputationId :: !ComputationID,
  gpLocalPath :: !NodePath
} deriving (Eq, Show)

{-| A mapping between a node ID and all the calculated occurences of this node
across the application. These occurences are expected to be reusable within the
computation backend.
-}
type NodeMap = Map NodeId (NonEmpty GlobalPath)

{-| The successful transform of a high-level functional graph into
a lower-level, optimized version.

One can see the progress using the phases also returned.
-}
data GraphTransformSuccess = GraphTransformSuccess {
  gtsNodes :: !ComputeGraph,
  gtsNodeMapUpdate :: !NodeMap,
  gtsCompilerSteps :: ![(PAI.CompilingPhase, ComputeGraph)]
}

{-| The result of a failure in the compiler. On top of the error, it also
returns information about the successful compiler steps.
-}
data GraphTransformFailure = GraphTransformFailure {
  gtfMessage :: !NodeError,
  gtfCompilerSteps :: ![(PAI.CompilingPhase, ComputeGraph)]
}

{-| internal

A graph of computations. This graph is a direct acyclic graph. Each node is
associated to a global path.

Note: this is a parsed representation that has already called the builders.
Note sure if this is the right design here.
-}
type ComputeGraph = ComputeDag OperatorNode StructureEdge


instance Default CompilerConf where
  def = CompilerConf {
      ccUseNodePruning = False
    }

instance FromProto PC.SessionId LocalSessionId where
  fromProto (PC.SessionId x) = pure $ LocalSessionId x

instance ToProto PC.SessionId LocalSessionId where
  toProto = PC.SessionId . unLocalSession
