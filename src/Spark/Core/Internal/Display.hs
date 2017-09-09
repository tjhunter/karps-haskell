{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MultiParamTypeClasses #-}

{-| This module takes compute graph and turns them into a string representation
 that is easy to display using TensorBoard. See the python and Haskell
 frontends to see how to do that given the string representations.
-}
module Spark.Core.Internal.Display(
  displayGraph
) where

import qualified Data.Map as M
import qualified Data.Vector as V
import Data.Text(Text)
import Data.Monoid((<>))
import Data.Functor.Identity(runIdentity, Identity)

import qualified Proto.Tensorflow.Core.Framework.Graph as PG
import qualified Proto.Tensorflow.Core.Framework.NodeDef as PN
import Spark.Core.Internal.ContextStructures(ComputeGraph)
import Spark.Core.Internal.ComputeDag(computeGraphMapVertices, ComputeDag(cdVertices))
import Spark.Core.Internal.DAGStructures(Vertex(vertexData))
import Spark.Core.Internal.OpStructures()
import Spark.Core.Internal.DatasetStructures(OperatorNode(..), StructureEdge(..))
import Spark.Core.StructuresInternal(prettyNodePath)

{-| Converts a compute graph to a form that can be displayed by TensorBoard.
-}
displayGraph :: ComputeGraph -> PG.GraphDef
displayGraph cg = PG.GraphDef nodes where
  f :: OperatorNode -> [(PN.NodeDef, StructureEdge)] -> Identity PN.NodeDef
  f on l = pure $ _displayNode on parents logical where
             f' edgeType = PN._NodeDef'name . fst <$> filter ((edgeType ==).snd) l
             parents = f' ParentEdge
             logical = f' LogicalEdge
  cg2 = runIdentity $ computeGraphMapVertices cg f
  nodes = vertexData <$> V.toList (cdVertices cg2)


_displayNode :: OperatorNode -> [Text] -> [Text] -> PN.NodeDef
_displayNode on parents logical = PN.NodeDef {
    PN._NodeDef'name = prettyNodePath (onPath on),
    PN._NodeDef'op = "", -- TODO: this is missing here
    -- The ^ caret indicates logical deps.
    PN._NodeDef'input = parents ++ (("^" <>) <$> logical),
    PN._NodeDef'device = "",
    PN._NodeDef'attr = M.empty
  } -- TODO: add a lot more info here.
