{- This file was auto-generated from karps/proto/api_internal.proto by the proto-lens-protoc program. -}
{-# LANGUAGE ScopedTypeVariables, DataKinds, TypeFamilies,
  UndecidableInstances, MultiParamTypeClasses, FlexibleContexts,
  FlexibleInstances, PatternSynonyms, MagicHash, NoImplicitPrelude
  #-}
{-# OPTIONS_GHC -fno-warn-unused-imports #-}
module Proto.Karps.Proto.ApiInternal where
import qualified Data.ProtoLens.Reexport.Prelude as Prelude
import qualified Data.ProtoLens.Reexport.Data.Int as Data.Int
import qualified Data.ProtoLens.Reexport.Data.Word as Data.Word
import qualified Data.ProtoLens.Reexport.Data.ProtoLens
       as Data.ProtoLens
import qualified
       Data.ProtoLens.Reexport.Data.ProtoLens.Message.Enum
       as Data.ProtoLens.Message.Enum
import qualified Data.ProtoLens.Reexport.Lens.Family2
       as Lens.Family2
import qualified Data.ProtoLens.Reexport.Lens.Family2.Unchecked
       as Lens.Family2.Unchecked
import qualified Data.ProtoLens.Reexport.Data.Default.Class
       as Data.Default.Class
import qualified Data.ProtoLens.Reexport.Data.Text as Data.Text
import qualified Data.ProtoLens.Reexport.Data.Map as Data.Map
import qualified Data.ProtoLens.Reexport.Data.ByteString
       as Data.ByteString
import qualified Data.ProtoLens.Reexport.Lens.Labels as Lens.Labels
import qualified Proto.Karps.Proto.Computation
import qualified Proto.Karps.Proto.Graph

data AnalysisMessage = AnalysisMessage{_AnalysisMessage'computation
                                       ::
                                       !(Prelude.Maybe Proto.Karps.Proto.Computation.ComputationId),
                                       _AnalysisMessage'session ::
                                       !(Prelude.Maybe Proto.Karps.Proto.Computation.SessionId),
                                       _AnalysisMessage'relevantId :: !(Prelude.Maybe NodeId),
                                       _AnalysisMessage'path ::
                                       !(Prelude.Maybe Proto.Karps.Proto.Graph.Path),
                                       _AnalysisMessage'content :: !Data.Text.Text,
                                       _AnalysisMessage'level :: !MessageSeverity}
                     deriving (Prelude.Show, Prelude.Eq, Prelude.Ord)

instance (a ~ Proto.Karps.Proto.Computation.ComputationId,
          b ~ Proto.Karps.Proto.Computation.ComputationId,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "computation" f AnalysisMessage AnalysisMessage
         a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _AnalysisMessage'computation
                 (\ x__ y__ -> x__{_AnalysisMessage'computation = y__}))
              (Data.ProtoLens.maybeLens Data.Default.Class.def)

instance (a ~
            Prelude.Maybe Proto.Karps.Proto.Computation.ComputationId,
          b ~ Prelude.Maybe Proto.Karps.Proto.Computation.ComputationId,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "maybe'computation" f AnalysisMessage
         AnalysisMessage a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _AnalysisMessage'computation
                 (\ x__ y__ -> x__{_AnalysisMessage'computation = y__}))
              Prelude.id

instance (a ~ Proto.Karps.Proto.Computation.SessionId,
          b ~ Proto.Karps.Proto.Computation.SessionId, Prelude.Functor f) =>
         Lens.Labels.HasLens "session" f AnalysisMessage AnalysisMessage a b
         where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _AnalysisMessage'session
                 (\ x__ y__ -> x__{_AnalysisMessage'session = y__}))
              (Data.ProtoLens.maybeLens Data.Default.Class.def)

instance (a ~
            Prelude.Maybe Proto.Karps.Proto.Computation.SessionId,
          b ~ Prelude.Maybe Proto.Karps.Proto.Computation.SessionId,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "maybe'session" f AnalysisMessage
         AnalysisMessage a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _AnalysisMessage'session
                 (\ x__ y__ -> x__{_AnalysisMessage'session = y__}))
              Prelude.id

instance (a ~ NodeId, b ~ NodeId, Prelude.Functor f) =>
         Lens.Labels.HasLens "relevantId" f AnalysisMessage AnalysisMessage
         a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _AnalysisMessage'relevantId
                 (\ x__ y__ -> x__{_AnalysisMessage'relevantId = y__}))
              (Data.ProtoLens.maybeLens Data.Default.Class.def)

instance (a ~ Prelude.Maybe NodeId, b ~ Prelude.Maybe NodeId,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "maybe'relevantId" f AnalysisMessage
         AnalysisMessage a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _AnalysisMessage'relevantId
                 (\ x__ y__ -> x__{_AnalysisMessage'relevantId = y__}))
              Prelude.id

instance (a ~ Proto.Karps.Proto.Graph.Path,
          b ~ Proto.Karps.Proto.Graph.Path, Prelude.Functor f) =>
         Lens.Labels.HasLens "path" f AnalysisMessage AnalysisMessage a b
         where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _AnalysisMessage'path
                 (\ x__ y__ -> x__{_AnalysisMessage'path = y__}))
              (Data.ProtoLens.maybeLens Data.Default.Class.def)

instance (a ~ Prelude.Maybe Proto.Karps.Proto.Graph.Path,
          b ~ Prelude.Maybe Proto.Karps.Proto.Graph.Path,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "maybe'path" f AnalysisMessage AnalysisMessage
         a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _AnalysisMessage'path
                 (\ x__ y__ -> x__{_AnalysisMessage'path = y__}))
              Prelude.id

instance (a ~ Data.Text.Text, b ~ Data.Text.Text,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "content" f AnalysisMessage AnalysisMessage a b
         where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _AnalysisMessage'content
                 (\ x__ y__ -> x__{_AnalysisMessage'content = y__}))
              Prelude.id

instance (a ~ MessageSeverity, b ~ MessageSeverity,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "level" f AnalysisMessage AnalysisMessage a b
         where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _AnalysisMessage'level
                 (\ x__ y__ -> x__{_AnalysisMessage'level = y__}))
              Prelude.id

instance Data.Default.Class.Default AnalysisMessage where
        def
          = AnalysisMessage{_AnalysisMessage'computation = Prelude.Nothing,
                            _AnalysisMessage'session = Prelude.Nothing,
                            _AnalysisMessage'relevantId = Prelude.Nothing,
                            _AnalysisMessage'path = Prelude.Nothing,
                            _AnalysisMessage'content = Data.ProtoLens.fieldDefault,
                            _AnalysisMessage'level = Data.Default.Class.def}

instance Data.ProtoLens.Message AnalysisMessage where
        descriptor
          = let computation__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "computation"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor
                           Proto.Karps.Proto.Computation.ComputationId)
                      (Data.ProtoLens.OptionalField maybe'computation)
                      :: Data.ProtoLens.FieldDescriptor AnalysisMessage
                session__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "session"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor
                           Proto.Karps.Proto.Computation.SessionId)
                      (Data.ProtoLens.OptionalField maybe'session)
                      :: Data.ProtoLens.FieldDescriptor AnalysisMessage
                relevantId__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "relevant_id"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor NodeId)
                      (Data.ProtoLens.OptionalField maybe'relevantId)
                      :: Data.ProtoLens.FieldDescriptor AnalysisMessage
                path__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "path"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor Proto.Karps.Proto.Graph.Path)
                      (Data.ProtoLens.OptionalField maybe'path)
                      :: Data.ProtoLens.FieldDescriptor AnalysisMessage
                content__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "content"
                      (Data.ProtoLens.StringField ::
                         Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
                      (Data.ProtoLens.PlainField Data.ProtoLens.Optional content)
                      :: Data.ProtoLens.FieldDescriptor AnalysisMessage
                level__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "level"
                      (Data.ProtoLens.EnumField ::
                         Data.ProtoLens.FieldTypeDescriptor MessageSeverity)
                      (Data.ProtoLens.PlainField Data.ProtoLens.Optional level)
                      :: Data.ProtoLens.FieldDescriptor AnalysisMessage
              in
              Data.ProtoLens.MessageDescriptor
                (Data.Text.pack "karps.core.AnalysisMessage")
                (Data.Map.fromList
                   [(Data.ProtoLens.Tag 1, computation__field_descriptor),
                    (Data.ProtoLens.Tag 2, session__field_descriptor),
                    (Data.ProtoLens.Tag 3, relevantId__field_descriptor),
                    (Data.ProtoLens.Tag 4, path__field_descriptor),
                    (Data.ProtoLens.Tag 5, content__field_descriptor),
                    (Data.ProtoLens.Tag 6, level__field_descriptor)])
                (Data.Map.fromList
                   [("computation", computation__field_descriptor),
                    ("session", session__field_descriptor),
                    ("relevant_id", relevantId__field_descriptor),
                    ("path", path__field_descriptor),
                    ("content", content__field_descriptor),
                    ("level", level__field_descriptor)])

data GraphTransformResponse = GraphTransformResponse{_GraphTransformResponse'pinnedGraph
                                                     ::
                                                     !(Prelude.Maybe Proto.Karps.Proto.Graph.Graph),
                                                     _GraphTransformResponse'nodeMap ::
                                                     ![NodeMapItem],
                                                     _GraphTransformResponse'messages ::
                                                     ![AnalysisMessage]}
                            deriving (Prelude.Show, Prelude.Eq, Prelude.Ord)

instance (a ~ Proto.Karps.Proto.Graph.Graph,
          b ~ Proto.Karps.Proto.Graph.Graph, Prelude.Functor f) =>
         Lens.Labels.HasLens "pinnedGraph" f GraphTransformResponse
         GraphTransformResponse a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _GraphTransformResponse'pinnedGraph
                 (\ x__ y__ -> x__{_GraphTransformResponse'pinnedGraph = y__}))
              (Data.ProtoLens.maybeLens Data.Default.Class.def)

instance (a ~ Prelude.Maybe Proto.Karps.Proto.Graph.Graph,
          b ~ Prelude.Maybe Proto.Karps.Proto.Graph.Graph,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "maybe'pinnedGraph" f GraphTransformResponse
         GraphTransformResponse a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _GraphTransformResponse'pinnedGraph
                 (\ x__ y__ -> x__{_GraphTransformResponse'pinnedGraph = y__}))
              Prelude.id

instance (a ~ [NodeMapItem], b ~ [NodeMapItem],
          Prelude.Functor f) =>
         Lens.Labels.HasLens "nodeMap" f GraphTransformResponse
         GraphTransformResponse a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _GraphTransformResponse'nodeMap
                 (\ x__ y__ -> x__{_GraphTransformResponse'nodeMap = y__}))
              Prelude.id

instance (a ~ [AnalysisMessage], b ~ [AnalysisMessage],
          Prelude.Functor f) =>
         Lens.Labels.HasLens "messages" f GraphTransformResponse
         GraphTransformResponse a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _GraphTransformResponse'messages
                 (\ x__ y__ -> x__{_GraphTransformResponse'messages = y__}))
              Prelude.id

instance Data.Default.Class.Default GraphTransformResponse where
        def
          = GraphTransformResponse{_GraphTransformResponse'pinnedGraph =
                                     Prelude.Nothing,
                                   _GraphTransformResponse'nodeMap = [],
                                   _GraphTransformResponse'messages = []}

instance Data.ProtoLens.Message GraphTransformResponse where
        descriptor
          = let pinnedGraph__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "pinned_graph"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor Proto.Karps.Proto.Graph.Graph)
                      (Data.ProtoLens.OptionalField maybe'pinnedGraph)
                      :: Data.ProtoLens.FieldDescriptor GraphTransformResponse
                nodeMap__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "node_map"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor NodeMapItem)
                      (Data.ProtoLens.RepeatedField Data.ProtoLens.Unpacked nodeMap)
                      :: Data.ProtoLens.FieldDescriptor GraphTransformResponse
                messages__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "messages"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor AnalysisMessage)
                      (Data.ProtoLens.RepeatedField Data.ProtoLens.Unpacked messages)
                      :: Data.ProtoLens.FieldDescriptor GraphTransformResponse
              in
              Data.ProtoLens.MessageDescriptor
                (Data.Text.pack "karps.core.GraphTransformResponse")
                (Data.Map.fromList
                   [(Data.ProtoLens.Tag 1, pinnedGraph__field_descriptor),
                    (Data.ProtoLens.Tag 2, nodeMap__field_descriptor),
                    (Data.ProtoLens.Tag 3, messages__field_descriptor)])
                (Data.Map.fromList
                   [("pinned_graph", pinnedGraph__field_descriptor),
                    ("node_map", nodeMap__field_descriptor),
                    ("messages", messages__field_descriptor)])

data MessageSeverity = INFO
                     | WARNING
                     | FATAL
                     deriving (Prelude.Show, Prelude.Eq, Prelude.Ord)

instance Data.Default.Class.Default MessageSeverity where
        def = INFO

instance Data.ProtoLens.FieldDefault MessageSeverity where
        fieldDefault = INFO

instance Data.ProtoLens.MessageEnum MessageSeverity where
        maybeToEnum 0 = Prelude.Just INFO
        maybeToEnum 1 = Prelude.Just WARNING
        maybeToEnum 2 = Prelude.Just FATAL
        maybeToEnum _ = Prelude.Nothing
        showEnum INFO = "INFO"
        showEnum WARNING = "WARNING"
        showEnum FATAL = "FATAL"
        readEnum "INFO" = Prelude.Just INFO
        readEnum "WARNING" = Prelude.Just WARNING
        readEnum "FATAL" = Prelude.Just FATAL
        readEnum _ = Prelude.Nothing

instance Prelude.Enum MessageSeverity where
        toEnum k__
          = Prelude.maybe
              (Prelude.error
                 ((Prelude.++) "toEnum: unknown value for enum MessageSeverity: "
                    (Prelude.show k__)))
              Prelude.id
              (Data.ProtoLens.maybeToEnum k__)
        fromEnum INFO = 0
        fromEnum WARNING = 1
        fromEnum FATAL = 2
        succ FATAL
          = Prelude.error
              "MessageSeverity.succ: bad argument FATAL. This value would be out of bounds."
        succ INFO = WARNING
        succ WARNING = FATAL
        pred INFO
          = Prelude.error
              "MessageSeverity.pred: bad argument INFO. This value would be out of bounds."
        pred WARNING = INFO
        pred FATAL = WARNING
        enumFrom = Data.ProtoLens.Message.Enum.messageEnumFrom
        enumFromTo = Data.ProtoLens.Message.Enum.messageEnumFromTo
        enumFromThen = Data.ProtoLens.Message.Enum.messageEnumFromThen
        enumFromThenTo = Data.ProtoLens.Message.Enum.messageEnumFromThenTo

instance Prelude.Bounded MessageSeverity where
        minBound = INFO
        maxBound = FATAL

data NodeId = NodeId{_NodeId'value :: !Data.Text.Text}
            deriving (Prelude.Show, Prelude.Eq, Prelude.Ord)

instance (a ~ Data.Text.Text, b ~ Data.Text.Text,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "value" f NodeId NodeId a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _NodeId'value
                 (\ x__ y__ -> x__{_NodeId'value = y__}))
              Prelude.id

instance Data.Default.Class.Default NodeId where
        def = NodeId{_NodeId'value = Data.ProtoLens.fieldDefault}

instance Data.ProtoLens.Message NodeId where
        descriptor
          = let value__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "value"
                      (Data.ProtoLens.StringField ::
                         Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
                      (Data.ProtoLens.PlainField Data.ProtoLens.Optional value)
                      :: Data.ProtoLens.FieldDescriptor NodeId
              in
              Data.ProtoLens.MessageDescriptor
                (Data.Text.pack "karps.core.NodeId")
                (Data.Map.fromList
                   [(Data.ProtoLens.Tag 1, value__field_descriptor)])
                (Data.Map.fromList [("value", value__field_descriptor)])

data NodeMapItem = NodeMapItem{_NodeMapItem'node ::
                               !(Prelude.Maybe NodeId),
                               _NodeMapItem'path :: !(Prelude.Maybe Proto.Karps.Proto.Graph.Path),
                               _NodeMapItem'computation ::
                               !(Prelude.Maybe Proto.Karps.Proto.Computation.ComputationId),
                               _NodeMapItem'session ::
                               !(Prelude.Maybe Proto.Karps.Proto.Computation.SessionId)}
                 deriving (Prelude.Show, Prelude.Eq, Prelude.Ord)

instance (a ~ NodeId, b ~ NodeId, Prelude.Functor f) =>
         Lens.Labels.HasLens "node" f NodeMapItem NodeMapItem a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _NodeMapItem'node
                 (\ x__ y__ -> x__{_NodeMapItem'node = y__}))
              (Data.ProtoLens.maybeLens Data.Default.Class.def)

instance (a ~ Prelude.Maybe NodeId, b ~ Prelude.Maybe NodeId,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "maybe'node" f NodeMapItem NodeMapItem a b
         where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _NodeMapItem'node
                 (\ x__ y__ -> x__{_NodeMapItem'node = y__}))
              Prelude.id

instance (a ~ Proto.Karps.Proto.Graph.Path,
          b ~ Proto.Karps.Proto.Graph.Path, Prelude.Functor f) =>
         Lens.Labels.HasLens "path" f NodeMapItem NodeMapItem a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _NodeMapItem'path
                 (\ x__ y__ -> x__{_NodeMapItem'path = y__}))
              (Data.ProtoLens.maybeLens Data.Default.Class.def)

instance (a ~ Prelude.Maybe Proto.Karps.Proto.Graph.Path,
          b ~ Prelude.Maybe Proto.Karps.Proto.Graph.Path,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "maybe'path" f NodeMapItem NodeMapItem a b
         where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _NodeMapItem'path
                 (\ x__ y__ -> x__{_NodeMapItem'path = y__}))
              Prelude.id

instance (a ~ Proto.Karps.Proto.Computation.ComputationId,
          b ~ Proto.Karps.Proto.Computation.ComputationId,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "computation" f NodeMapItem NodeMapItem a b
         where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _NodeMapItem'computation
                 (\ x__ y__ -> x__{_NodeMapItem'computation = y__}))
              (Data.ProtoLens.maybeLens Data.Default.Class.def)

instance (a ~
            Prelude.Maybe Proto.Karps.Proto.Computation.ComputationId,
          b ~ Prelude.Maybe Proto.Karps.Proto.Computation.ComputationId,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "maybe'computation" f NodeMapItem NodeMapItem a
         b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _NodeMapItem'computation
                 (\ x__ y__ -> x__{_NodeMapItem'computation = y__}))
              Prelude.id

instance (a ~ Proto.Karps.Proto.Computation.SessionId,
          b ~ Proto.Karps.Proto.Computation.SessionId, Prelude.Functor f) =>
         Lens.Labels.HasLens "session" f NodeMapItem NodeMapItem a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _NodeMapItem'session
                 (\ x__ y__ -> x__{_NodeMapItem'session = y__}))
              (Data.ProtoLens.maybeLens Data.Default.Class.def)

instance (a ~
            Prelude.Maybe Proto.Karps.Proto.Computation.SessionId,
          b ~ Prelude.Maybe Proto.Karps.Proto.Computation.SessionId,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "maybe'session" f NodeMapItem NodeMapItem a b
         where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _NodeMapItem'session
                 (\ x__ y__ -> x__{_NodeMapItem'session = y__}))
              Prelude.id

instance Data.Default.Class.Default NodeMapItem where
        def
          = NodeMapItem{_NodeMapItem'node = Prelude.Nothing,
                        _NodeMapItem'path = Prelude.Nothing,
                        _NodeMapItem'computation = Prelude.Nothing,
                        _NodeMapItem'session = Prelude.Nothing}

instance Data.ProtoLens.Message NodeMapItem where
        descriptor
          = let node__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "node"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor NodeId)
                      (Data.ProtoLens.OptionalField maybe'node)
                      :: Data.ProtoLens.FieldDescriptor NodeMapItem
                path__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "path"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor Proto.Karps.Proto.Graph.Path)
                      (Data.ProtoLens.OptionalField maybe'path)
                      :: Data.ProtoLens.FieldDescriptor NodeMapItem
                computation__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "computation"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor
                           Proto.Karps.Proto.Computation.ComputationId)
                      (Data.ProtoLens.OptionalField maybe'computation)
                      :: Data.ProtoLens.FieldDescriptor NodeMapItem
                session__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "session"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor
                           Proto.Karps.Proto.Computation.SessionId)
                      (Data.ProtoLens.OptionalField maybe'session)
                      :: Data.ProtoLens.FieldDescriptor NodeMapItem
              in
              Data.ProtoLens.MessageDescriptor
                (Data.Text.pack "karps.core.NodeMapItem")
                (Data.Map.fromList
                   [(Data.ProtoLens.Tag 1, node__field_descriptor),
                    (Data.ProtoLens.Tag 2, path__field_descriptor),
                    (Data.ProtoLens.Tag 3, computation__field_descriptor),
                    (Data.ProtoLens.Tag 4, session__field_descriptor)])
                (Data.Map.fromList
                   [("node", node__field_descriptor),
                    ("path", path__field_descriptor),
                    ("computation", computation__field_descriptor),
                    ("session", session__field_descriptor)])

data PerformGraphTransform = PerformGraphTransform{_PerformGraphTransform'session
                                                   ::
                                                   !(Prelude.Maybe
                                                       Proto.Karps.Proto.Computation.SessionId),
                                                   _PerformGraphTransform'computation ::
                                                   !(Prelude.Maybe
                                                       Proto.Karps.Proto.Computation.ComputationId),
                                                   _PerformGraphTransform'functionalGraph ::
                                                   !(Prelude.Maybe Proto.Karps.Proto.Graph.Graph),
                                                   _PerformGraphTransform'availableNodes ::
                                                   ![NodeMapItem],
                                                   _PerformGraphTransform'requestedPaths ::
                                                   ![Proto.Karps.Proto.Graph.Path]}
                           deriving (Prelude.Show, Prelude.Eq, Prelude.Ord)

instance (a ~ Proto.Karps.Proto.Computation.SessionId,
          b ~ Proto.Karps.Proto.Computation.SessionId, Prelude.Functor f) =>
         Lens.Labels.HasLens "session" f PerformGraphTransform
         PerformGraphTransform a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _PerformGraphTransform'session
                 (\ x__ y__ -> x__{_PerformGraphTransform'session = y__}))
              (Data.ProtoLens.maybeLens Data.Default.Class.def)

instance (a ~
            Prelude.Maybe Proto.Karps.Proto.Computation.SessionId,
          b ~ Prelude.Maybe Proto.Karps.Proto.Computation.SessionId,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "maybe'session" f PerformGraphTransform
         PerformGraphTransform a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _PerformGraphTransform'session
                 (\ x__ y__ -> x__{_PerformGraphTransform'session = y__}))
              Prelude.id

instance (a ~ Proto.Karps.Proto.Computation.ComputationId,
          b ~ Proto.Karps.Proto.Computation.ComputationId,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "computation" f PerformGraphTransform
         PerformGraphTransform a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _PerformGraphTransform'computation
                 (\ x__ y__ -> x__{_PerformGraphTransform'computation = y__}))
              (Data.ProtoLens.maybeLens Data.Default.Class.def)

instance (a ~
            Prelude.Maybe Proto.Karps.Proto.Computation.ComputationId,
          b ~ Prelude.Maybe Proto.Karps.Proto.Computation.ComputationId,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "maybe'computation" f PerformGraphTransform
         PerformGraphTransform a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _PerformGraphTransform'computation
                 (\ x__ y__ -> x__{_PerformGraphTransform'computation = y__}))
              Prelude.id

instance (a ~ Proto.Karps.Proto.Graph.Graph,
          b ~ Proto.Karps.Proto.Graph.Graph, Prelude.Functor f) =>
         Lens.Labels.HasLens "functionalGraph" f PerformGraphTransform
         PerformGraphTransform a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _PerformGraphTransform'functionalGraph
                 (\ x__ y__ -> x__{_PerformGraphTransform'functionalGraph = y__}))
              (Data.ProtoLens.maybeLens Data.Default.Class.def)

instance (a ~ Prelude.Maybe Proto.Karps.Proto.Graph.Graph,
          b ~ Prelude.Maybe Proto.Karps.Proto.Graph.Graph,
          Prelude.Functor f) =>
         Lens.Labels.HasLens "maybe'functionalGraph" f PerformGraphTransform
         PerformGraphTransform a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _PerformGraphTransform'functionalGraph
                 (\ x__ y__ -> x__{_PerformGraphTransform'functionalGraph = y__}))
              Prelude.id

instance (a ~ [NodeMapItem], b ~ [NodeMapItem],
          Prelude.Functor f) =>
         Lens.Labels.HasLens "availableNodes" f PerformGraphTransform
         PerformGraphTransform a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _PerformGraphTransform'availableNodes
                 (\ x__ y__ -> x__{_PerformGraphTransform'availableNodes = y__}))
              Prelude.id

instance (a ~ [Proto.Karps.Proto.Graph.Path],
          b ~ [Proto.Karps.Proto.Graph.Path], Prelude.Functor f) =>
         Lens.Labels.HasLens "requestedPaths" f PerformGraphTransform
         PerformGraphTransform a b where
        lensOf _
          = (Prelude..)
              (Lens.Family2.Unchecked.lens _PerformGraphTransform'requestedPaths
                 (\ x__ y__ -> x__{_PerformGraphTransform'requestedPaths = y__}))
              Prelude.id

instance Data.Default.Class.Default PerformGraphTransform where
        def
          = PerformGraphTransform{_PerformGraphTransform'session =
                                    Prelude.Nothing,
                                  _PerformGraphTransform'computation = Prelude.Nothing,
                                  _PerformGraphTransform'functionalGraph = Prelude.Nothing,
                                  _PerformGraphTransform'availableNodes = [],
                                  _PerformGraphTransform'requestedPaths = []}

instance Data.ProtoLens.Message PerformGraphTransform where
        descriptor
          = let session__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "session"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor
                           Proto.Karps.Proto.Computation.SessionId)
                      (Data.ProtoLens.OptionalField maybe'session)
                      :: Data.ProtoLens.FieldDescriptor PerformGraphTransform
                computation__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "computation"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor
                           Proto.Karps.Proto.Computation.ComputationId)
                      (Data.ProtoLens.OptionalField maybe'computation)
                      :: Data.ProtoLens.FieldDescriptor PerformGraphTransform
                functionalGraph__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "functional_graph"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor Proto.Karps.Proto.Graph.Graph)
                      (Data.ProtoLens.OptionalField maybe'functionalGraph)
                      :: Data.ProtoLens.FieldDescriptor PerformGraphTransform
                availableNodes__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "available_nodes"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor NodeMapItem)
                      (Data.ProtoLens.RepeatedField Data.ProtoLens.Unpacked
                         availableNodes)
                      :: Data.ProtoLens.FieldDescriptor PerformGraphTransform
                requestedPaths__field_descriptor
                  = Data.ProtoLens.FieldDescriptor "requested_paths"
                      (Data.ProtoLens.MessageField ::
                         Data.ProtoLens.FieldTypeDescriptor Proto.Karps.Proto.Graph.Path)
                      (Data.ProtoLens.RepeatedField Data.ProtoLens.Unpacked
                         requestedPaths)
                      :: Data.ProtoLens.FieldDescriptor PerformGraphTransform
              in
              Data.ProtoLens.MessageDescriptor
                (Data.Text.pack "karps.core.PerformGraphTransform")
                (Data.Map.fromList
                   [(Data.ProtoLens.Tag 1, session__field_descriptor),
                    (Data.ProtoLens.Tag 2, computation__field_descriptor),
                    (Data.ProtoLens.Tag 3, functionalGraph__field_descriptor),
                    (Data.ProtoLens.Tag 4, availableNodes__field_descriptor),
                    (Data.ProtoLens.Tag 5, requestedPaths__field_descriptor)])
                (Data.Map.fromList
                   [("session", session__field_descriptor),
                    ("computation", computation__field_descriptor),
                    ("functional_graph", functionalGraph__field_descriptor),
                    ("available_nodes", availableNodes__field_descriptor),
                    ("requested_paths", requestedPaths__field_descriptor)])

availableNodes ::
               forall f s t a b .
                 Lens.Labels.HasLens "availableNodes" f s t a b =>
                 Lens.Family2.LensLike f s t a b
availableNodes
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "availableNodes")

computation ::
            forall f s t a b . Lens.Labels.HasLens "computation" f s t a b =>
              Lens.Family2.LensLike f s t a b
computation
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "computation")

content ::
        forall f s t a b . Lens.Labels.HasLens "content" f s t a b =>
          Lens.Family2.LensLike f s t a b
content
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "content")

functionalGraph ::
                forall f s t a b .
                  Lens.Labels.HasLens "functionalGraph" f s t a b =>
                  Lens.Family2.LensLike f s t a b
functionalGraph
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "functionalGraph")

level ::
      forall f s t a b . Lens.Labels.HasLens "level" f s t a b =>
        Lens.Family2.LensLike f s t a b
level
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "level")

maybe'computation ::
                  forall f s t a b .
                    Lens.Labels.HasLens "maybe'computation" f s t a b =>
                    Lens.Family2.LensLike f s t a b
maybe'computation
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "maybe'computation")

maybe'functionalGraph ::
                      forall f s t a b .
                        Lens.Labels.HasLens "maybe'functionalGraph" f s t a b =>
                        Lens.Family2.LensLike f s t a b
maybe'functionalGraph
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) ::
         (Lens.Labels.Proxy#) "maybe'functionalGraph")

maybe'node ::
           forall f s t a b . Lens.Labels.HasLens "maybe'node" f s t a b =>
             Lens.Family2.LensLike f s t a b
maybe'node
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "maybe'node")

maybe'path ::
           forall f s t a b . Lens.Labels.HasLens "maybe'path" f s t a b =>
             Lens.Family2.LensLike f s t a b
maybe'path
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "maybe'path")

maybe'pinnedGraph ::
                  forall f s t a b .
                    Lens.Labels.HasLens "maybe'pinnedGraph" f s t a b =>
                    Lens.Family2.LensLike f s t a b
maybe'pinnedGraph
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "maybe'pinnedGraph")

maybe'relevantId ::
                 forall f s t a b .
                   Lens.Labels.HasLens "maybe'relevantId" f s t a b =>
                   Lens.Family2.LensLike f s t a b
maybe'relevantId
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "maybe'relevantId")

maybe'session ::
              forall f s t a b . Lens.Labels.HasLens "maybe'session" f s t a b =>
                Lens.Family2.LensLike f s t a b
maybe'session
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "maybe'session")

messages ::
         forall f s t a b . Lens.Labels.HasLens "messages" f s t a b =>
           Lens.Family2.LensLike f s t a b
messages
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "messages")

node ::
     forall f s t a b . Lens.Labels.HasLens "node" f s t a b =>
       Lens.Family2.LensLike f s t a b
node
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "node")

nodeMap ::
        forall f s t a b . Lens.Labels.HasLens "nodeMap" f s t a b =>
          Lens.Family2.LensLike f s t a b
nodeMap
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "nodeMap")

path ::
     forall f s t a b . Lens.Labels.HasLens "path" f s t a b =>
       Lens.Family2.LensLike f s t a b
path
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "path")

pinnedGraph ::
            forall f s t a b . Lens.Labels.HasLens "pinnedGraph" f s t a b =>
              Lens.Family2.LensLike f s t a b
pinnedGraph
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "pinnedGraph")

relevantId ::
           forall f s t a b . Lens.Labels.HasLens "relevantId" f s t a b =>
             Lens.Family2.LensLike f s t a b
relevantId
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "relevantId")

requestedPaths ::
               forall f s t a b .
                 Lens.Labels.HasLens "requestedPaths" f s t a b =>
                 Lens.Family2.LensLike f s t a b
requestedPaths
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "requestedPaths")

session ::
        forall f s t a b . Lens.Labels.HasLens "session" f s t a b =>
          Lens.Family2.LensLike f s t a b
session
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "session")

value ::
      forall f s t a b . Lens.Labels.HasLens "value" f s t a b =>
        Lens.Family2.LensLike f s t a b
value
  = Lens.Labels.lensOf
      ((Lens.Labels.proxy#) :: (Lens.Labels.Proxy#) "value")