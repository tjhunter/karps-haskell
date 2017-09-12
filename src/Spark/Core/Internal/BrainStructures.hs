{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}

{-| The public data structures used by the Karps compiler.
-}
module Spark.Core.Internal.BrainStructures(
  CompilerConf(..),
  LocalSessionId,
  ResourcePath,
  ResourceStamp,
  ResourceList,
  -- ResourcesList,
  GlobalPath(..),
  NodeMap,
  GraphTransformSuccess(..),
  GraphTransformFailure(..),
  ComputeGraph,
  resourcePath,
  unResourcePath,
  makeSessionId
) where

import Data.Map.Strict(Map)
import Data.Text(Text, pack, unpack)
import Data.String(IsString(..))
import Data.Default
import Lens.Family2 ((^.), (&), (.~))

import Spark.Core.Internal.Utilities
import Spark.Core.Internal.ProtoUtils
import Spark.Core.Internal.ComputeDag(ComputeDag)
import Spark.Core.Internal.DatasetStructures(StructureEdge, OperatorNode)
import Spark.Core.StructuresInternal(NodeId, ComputationID, NodePath)
import Spark.Core.Try(NodeError(..), Try)
import qualified Proto.Karps.Proto.Computation as PC
import qualified Proto.Karps.Proto.ApiInternal as PAI
import qualified Proto.Karps.Proto.Io as PI

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
} deriving (Eq)

makeSessionId :: Text -> LocalSessionId
makeSessionId = LocalSessionId

data ResourcePath = ResourcePath Text deriving (Eq, Show, Ord)

-- TODO: could do more checks here about schema, etc.
resourcePath :: Text -> Try ResourcePath
resourcePath = pure . ResourcePath

unResourcePath :: ResourcePath -> Text
unResourcePath (ResourcePath txt) = txt

data ResourceStamp = ResourceStamp Text deriving (Eq, Show)

-- type ResourcesList = [(ResourcePath, ResourceStamp)]

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

type ResourceList = [(ResourcePath, ResourceStamp)]

instance Show LocalSessionId where
  show = unpack . unLocalSession

instance Default CompilerConf where
  def = CompilerConf {
      ccUseNodePruning = False
    }

instance IsString ResourcePath where
  fromString = ResourcePath . pack

instance FromProto PC.SessionId LocalSessionId where
  fromProto (PC.SessionId x) = pure $ LocalSessionId x

instance ToProto PC.SessionId LocalSessionId where
  toProto = PC.SessionId . unLocalSession

instance FromProto PI.ResourcePath ResourcePath where
  fromProto (PI.ResourcePath x) = pure $ ResourcePath x

instance ToProto PI.ResourcePath ResourcePath where
  toProto (ResourcePath x) = PI.ResourcePath x

instance FromProto PI.ResourceStamp ResourceStamp where
  fromProto (PI.ResourceStamp x) = pure $ ResourceStamp x

instance ToProto PI.ResourceStamp ResourceStamp where
  toProto (ResourceStamp x) = PI.ResourceStamp x

instance FromProto PAI.AnalyzeResourceResponse'FailedStatus (ResourcePath, NodeError) where
  fromProto fs = do
    rp <- extractMaybe' fs PAI.maybe'resource "resource"
    let e = fs ^. PAI.error
    return (rp, Error [] e)

instance ToProto PAI.AnalyzeResourceResponse'FailedStatus (ResourcePath, NodeError) where
  toProto (rp, Error _ e) = (def :: PAI.AnalyzeResourceResponse'FailedStatus)
    & PAI.resource .~ toProto rp
    & PAI.error .~ e

instance FromProto PAI.ResourceStatus (ResourcePath, ResourceStamp) where
  fromProto rs = do
    rp <- extractMaybe' rs PAI.maybe'resource "resource"
    rs' <- extractMaybe' rs PAI.maybe'stamp "stamp"
    return (rp, rs')

instance ToProto PAI.ResourceStatus (ResourcePath, ResourceStamp) where
  toProto (rp, rs) = (def :: PAI.ResourceStatus)
      & PAI.resource .~ toProto rp
      & PAI.stamp .~ toProto rs

instance FromProto PAI.AnalyzeResourceResponse [(ResourcePath, Try ResourceStamp)] where
  fromProto arr = do
    successes <- sequence $ fromProto <$> arr ^. PAI.successes
    failures <- sequence $ fromProto <$> arr ^. PAI.failures
    let successes' = [(rp, pure s) | (rp, s) <- successes]
    let failures' = [(rp, Left ne) | (rp, ne) <- failures]
    return $ successes' ++ failures'
