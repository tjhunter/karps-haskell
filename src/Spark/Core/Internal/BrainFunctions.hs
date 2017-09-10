{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}

{-| This file is the major entry point for the Karps compiler.

This part of the computation is stateless and does not depend on the
DSL or on the server.
-}
module Spark.Core.Internal.BrainFunctions(performTransform) where

import qualified Data.Map.Strict as M
import qualified Data.List.NonEmpty as N
import Data.Map.Strict(Map)
import Data.Text(Text)
import Data.Default
import Lens.Family2((&), (.~))
import Data.Functor.Identity(runIdentity, Identity)

import Spark.Core.Internal.BrainStructures
import Spark.Core.Internal.Utilities
import Spark.Core.Internal.ProtoUtils
import Spark.Core.Internal.ComputeDag(ComputeDag, computeGraphMapVertices, graphVertexData)
import Spark.Core.Internal.DatasetStd(localityToProto)
import Spark.Core.Internal.OpFunctions(simpleShowOp, extraNodeOpData)
import Spark.Core.Internal.DatasetStructures(StructureEdge(..), OperatorNode(onPath), onLocality, onType, onOp)
import Spark.Core.StructuresInternal(NodeId, ComputationID, NodePath)
import Spark.Core.Internal.Display(displayGraph)
import Spark.Core.Try(NodeError(..))
import qualified Proto.Karps.Proto.Computation as PC
import qualified Proto.Karps.Proto.Graph as PG
import qualified Proto.Karps.Proto.ApiInternal as PAI


{-| The main function that calls mos of the functions in the background.

For a list of all the steps done, look at the list of the steps in api_internal.proto
-}
performTransform ::
  CompilerConf ->
  NodeMap ->
  ComputeGraph ->
  Either GraphTransformFailure GraphTransformSuccess
performTransform = undefined



-- ********* INSTANCES ***********

instance ToProto PAI.AnalysisMessage NodeError where
  toProto ne = (def :: PAI.AnalysisMessage)
      & PAI.content .~ (eMessage ne)

instance FromProto PAI.NodeMapItem (NodeId, GlobalPath) where
  fromProto nmi = do
    nid <- extractMaybe' nmi PAI.maybe'node "node"
    np <- extractMaybe' nmi PAI.maybe'path "path"
    cid <- extractMaybe' nmi PAI.maybe'computation "computation"
    sid <- extractMaybe' nmi PAI.maybe'session "session"
    return (nid, GlobalPath sid cid np)

instance ToProto PAI.NodeMapItem (NodeId, GlobalPath) where
  toProto (nid, gp) = (def :: PAI.NodeMapItem)
      & PAI.node .~ toProto nid
      & PAI.path .~ toProto (gpLocalPath gp)
      & PAI.computation .~ toProto (gpComputationId gp)
      & PAI.session .~ toProto (gpSessionId gp)

instance ToProto PAI.CompilerStep (PAI.CompilingPhase, ComputeGraph) where
  toProto (phase, cg) = (def :: PAI.CompilerStep)
      & PAI.phase .~ phase
      & PAI.graph .~ toProto cg
      & PAI.graphDef .~ displayGraph cg

instance ToProto PAI.GraphTransformResponse GraphTransformSuccess where
  toProto gts = (def :: PAI.GraphTransformResponse)
    & PAI.pinnedGraph .~ toProto (gtsNodes gts)
    & PAI.nodeMap .~ (toProto <$> l)
    & PAI.steps .~ (toProto <$> gtsCompilerSteps gts) where
      l' = M.toList . (M.map N.toList) . gtsNodeMapUpdate $ gts
      l = [(nid, gp) | (nid, gps) <- l', gp <- gps ]

instance ToProto PAI.GraphTransformResponse GraphTransformFailure where
  toProto gtf = (def :: PAI.GraphTransformResponse)
    & PAI.steps .~ (toProto <$> gtfCompilerSteps gtf)
    & PAI.messages .~ [toProto (gtfMessage gtf)]

instance ToProto PG.Graph ComputeGraph where
  toProto cg = (def :: PG.Graph) & PG.nodes .~ l where
    f :: OperatorNode -> [((OperatorNode, PG.Node), StructureEdge)] -> Identity (OperatorNode, PG.Node)
    f on l' = pure (on, (def :: PG.Node)
              & PG.locality .~ localityToProto (onLocality on)
              & PG.path .~ toProto (onPath on)
              & PG.opName .~ simpleShowOp (onOp on)
              & PG.opExtra .~ toProto (extraNodeOpData (onOp on))
              & PG.parents .~ lparents
              & PG.logicalDependencies .~ ldeps
              & PG.inferedType .~ toProto (onType on)) where
                f' edgeType = toProto . onPath . fst . fst <$> filter ((edgeType ==) . snd) l'
                lparents = f' ParentEdge
                ldeps = f' LogicalEdge
    nodes = runIdentity $ computeGraphMapVertices cg f
    l = snd <$> graphVertexData nodes
