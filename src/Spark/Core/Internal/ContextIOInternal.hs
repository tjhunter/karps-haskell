{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleContexts #-}

module Spark.Core.Internal.ContextIOInternal(
  returnPure,
  createSparkSession,
  createSparkSession',
  executeCommand1,
  executeCommand1',
  checkDataStamps,
  createComputation,
  computationStats
) where

import qualified Data.Text as T
import qualified Network.Wreq as W
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS
import qualified Data.HashMap.Strict as HM
import qualified Data.HashSet as HS
import Control.Concurrent(threadDelay)
import Lens.Family2((^.), (&), (.~))
import Control.Monad(forM, forM_)
import Control.Monad.State(mapStateT, get)
import Control.Monad.Trans(lift)
import Control.Monad.Logger(runStdoutLoggingT, LoggingT, logDebugN, logInfoN, MonadLoggerIO)
import Control.Monad.Except(MonadError)
import Control.Monad.IO.Class
import Data.ProtoLens.Message(Message, def)
import Data.ProtoLens.Encoding(decodeMessage, encodeMessage)
import Data.ByteString.Lazy(ByteString)
import Data.Functor.Identity(runIdentity)
import Data.Word(Word8)
import Data.Maybe(mapMaybe)
import Data.Text(Text, pack)
import Network.Wreq(responseBody)
import Network.Wreq.Types(Postable)
import System.Random(randomIO)

import Spark.Core.Dataset
import Spark.Core.Internal.BrainStructures
import Spark.Core.Internal.BrainFunctions
import Spark.Core.Internal.Client
import Spark.Core.Internal.ContextInternal
import Spark.Core.Internal.ProtoUtils
import Spark.Core.Internal.ContextStructures
import Spark.Core.Internal.DatasetFunctions(untypedLocalData, nodePath)
import Spark.Core.Internal.DatasetStructures(UntypedLocalData, onShape, nodeOpNode)
import Spark.Core.Internal.OpStructures(DataInputStamp(..), NodeShape(..))
import Spark.Core.Internal.RowGenericsFrom(cellToValue)
import Spark.Core.Row
import Spark.Core.StructuresInternal
import Spark.Core.Try
import Spark.Core.Internal.Utilities
import qualified Proto.Karps.Proto.Interface as PI
import qualified Proto.Karps.Proto.Computation as PC
import qualified Proto.Karps.Proto.Computation as PC
import qualified Proto.Karps.Proto.ApiInternal as PAI
import qualified Proto.Karps.Proto.Io as PI

returnPure :: forall a. SparkStatePure a -> SparkState a
returnPure p = lift $ mapStateT (return . runIdentity) p

{- | Creates a new Spark session.

This session is unique, and it will not try to reconnect to an existing
session.
-}
createSparkSession :: (MonadLoggerIO m) => SparkSessionConf -> m SparkSession
createSparkSession conf = do
  sessionName <- case confRequestedSessionName conf of
    "" -> liftIO _randomSessionName
    x -> pure x
  let session = _createSparkSession conf sessionName 0
  logDebugN $ "Creating spark session"
  -- TODO get the current counter from remote
  _ <- _ensureSession session
  return session

{-| Convenience function for simple cases that do not require monad stacks.
-}
createSparkSession' :: SparkSessionConf -> IO SparkSession
createSparkSession' = _runLogger . createSparkSession

{- |
Executes a command:
- performs the transforms and the optimizations in the pure state
- sends the computation to the backend
- waits for the terminal nodes to reach a final state
- commits the final results to the state

If any failure is detected that is internal to Karps, it returns an error.
If the error comes from an underlying library (http stack, programming failure),
an exception may be thrown instead.
-}
executeCommand1 :: forall a. (FromSQL a) =>
  LocalData a -> SparkState (Try a)
executeCommand1 ld = do
    tcell <- executeCommand1' (untypedLocalData ld)
    return $ tcell >>= (tryEither . cellToValue)

-- The main function to launch computations.
executeCommand1' :: UntypedLocalData -> SparkState (Try Cell)
executeCommand1' ld = do
  logDebugN $ "compileCommand1: computing observable " <> show' ld
  let cgt = buildComputationGraph ld
  _ret cgt $ \cg -> do
    sourcesT <- fetchSourceInfo cg
    _ret sourcesT $ \sources -> do
      (_, compt) <- returnPure $ compileComputation sources cg
      _ret compt $ \comp -> do
        logDebugN $ "executeCommand1': computing observable " <> show' ld
        -- Run the computation.
        session <- get
        _ <- _sendComputation session comp
        waitForCompletion comp

waitForCompletion :: Computation -> SparkState (Try Cell)
waitForCompletion comp = do
  -- We track all the observables, instead of simply the targets.
  let obss = getObservables comp
  let trackedNodes = obss <&> \n ->
        (nodeId n, nodePath n,
         onShape (nodeOpNode n))
  nrs' <- _computationMultiStatus (cId comp) HS.empty trackedNodes
  logDebugN $ "waitForCompletion: nrs'=" <> show' nrs'
  -- Find the main result again in the list of everything.
  -- TODO: we actually do not need all the results, just target nodes.
  let targetNid = case cTerminalNodeIds comp of
        [nid] -> nid
        -- TODO: handle the case of multiple terminal targets
        l -> missing $ "waitForCompletion: missing multilist case with " <> show' l
  logDebugN $ "waitForCompletion: targetNid=" <> show' targetNid
  case filter (\z -> fst z == targetNid) nrs' of
    [(_, tc)] -> return tc
    l -> return $ tryError $ "Expected single result, got " <> show' l

{-| Exposed for debugging -}
computationStats ::
  ComputationID -> SparkState BatchComputationResult
computationStats cid = do
  logDebugN $ "computationStats: stats for " <> show' cid
  session <- get
  _computationStats session cid

{-| Exposed for debugging -}
createComputation :: ComputeGraph -> SparkState (Try Computation)
createComputation cg = returnPure $ prepareComputation cg

fetchSourceInfo :: ComputeGraph -> SparkState (Try ResourceList)
fetchSourceInfo cg = do
  let sources = inputSourcesRead cg
  if null sources
  then return (pure [])
  else do
    logDebugN $ "updateSourceInfo: found sources " <> show' sources
    -- Get the source stamps. Any error at this point is considered fatal.
    stampsRet <- checkDataStamps sources
    logDebugN $ "updateSourceInfo: retrieved stamps " <> show' stampsRet
    return $ sequence $ _f <$> stampsRet

_ret :: Try a -> (a -> SparkState (Try b)) -> SparkState (Try b)
_ret (Left x) _ = return (Left x)
_ret (Right x) f = f x

_f :: (a, Try b) -> Try (a, b)
_f (x, t) = case t of
                Right u -> Right (x, u)
                Left e -> Left e

_wrapTry :: Try a -> SparkState a
_wrapTry (Right x) = return x
_wrapTry (Left err) = do
  logDebugN $ "_wrapTry: got error: " <> show' err
  fail . T.unpack . eMessage $ err

{-| Given a list of paths, checks each of these paths on the file system of the
given Spark cluster to infer the status of these resources.

The primary role of this function is to check how recent these resources are
compared to some previous usage.
-}
checkDataStamps :: [ResourcePath] -> SparkState [(ResourcePath, Try ResourceStamp)]
checkDataStamps l = do
  let msg = (def :: PAI.AnalyzeResourcesRequest) & PAI.resources .~ (toProto <$> l)
  msg2 <- _sendBackend "check_resource" msg
  _wrapTry (fromProto msg2)

-- Send a proto to the backend, at the function name given.
_sendBackend :: (Message m1, Message m2) => Text -> m1 -> SparkState m2
_sendBackend function msg = do
  session <- get
  liftIO $ _runLogger $ _sendBackend' session function msg

_sendBackend' :: (MonadLoggerIO m, Message m1, Message m2) => SparkSession -> Text -> m1 -> m m2
_sendBackend' session function msg = do
  let url = _endPoint session function
  status <- liftIO $ W.post (T.unpack url) (encodeMessage msg)
  let s = status ^. responseBody
  case decodeMessage (LBS.toStrict s) of
    Left txt ->
      fail txt
    Right x -> return x

_randomSessionName :: IO Text
_randomSessionName = do
  ws <- forM [1..10] (\(_::Int) -> randomIO :: IO Word8)
  let ints = (`mod` 10) <$> ws
  return . T.pack $ "session" ++ concat (show <$> ints)

type DefLogger a = LoggingT IO a

_runLogger :: DefLogger a -> IO a
_runLogger = runStdoutLoggingT

_post :: (MonadIO m, Postable a) =>
  Text -> a -> m (W.Response ByteString)
_post url = liftIO . W.post (T.unpack url)

_get :: (MonadIO m) =>
  Text -> m (W.Response ByteString)
_get url = liftIO $ W.get (T.unpack url)

-- TODO move to more general utilities
-- Performs repeated polling until the result can be converted
-- to a certain other type.
-- Int controls the delay in milliseconds between each poll.
_pollMonad :: (MonadIO m) => m a -> Int -> (a -> Maybe b) -> m b
_pollMonad rec delayMillis check = do
  curr <- rec
  case check curr of
    Just res -> return res
    Nothing -> do
      _ <- liftIO $ threadDelay (delayMillis * 1000)
      _pollMonad rec delayMillis check


-- Creates a new session from a string containing a session ID.
_createSparkSession :: SparkSessionConf -> Text -> Integer -> SparkSession
_createSparkSession conf sessionId idx =
  SparkSession conf sid idx HM.empty where
    sid = LocalSessionId sessionId

_port :: SparkSession -> Text
_port = pack . show . confPort . ssConf

{-| The name of a function endpoint.
-}
_endPoint :: SparkSession -> Text -> Text
_endPoint sess function =
  T.concat [ (confEndPoint . ssConf) sess, ":", port,
    "/rest_proto/", function] where
      port = _sessionPortText sess


_sessionResourceCheck :: SparkSession -> Text
_sessionResourceCheck sess =
  let port = _port sess
      sid = (unLocalSession . ssId) sess
  in
    T.concat [
      (confEndPoint . ssConf) sess, ":", port,
      "/resources_status/", sid]

_sessionPortText :: SparkSession -> Text
_sessionPortText = pack . show . confPort . ssConf

-- Ensures that the server has instantiated a session with the given ID.
_ensureSession :: forall m. (MonadLoggerIO m) => SparkSession -> m ()
_ensureSession session = do
  let msg = (def :: PI.CreateSessionRequest)
  _ <- _sendBackend' session "CreateSession" msg :: m PI.CreateSessionResponse
  return ()


_sendComputation :: (MonadLoggerIO m) => SparkSession -> Computation -> m ()
_sendComputation session comp = do
  logInfoN $ "Sending computations with nodes: " <> show' (cNodes comp)
  -- TODO: fill the content
  let msg = (def :: PI.CreateComputationRequest)
  x <- _sendBackend' session "CreateComputation" msg
  let _ = x :: PI.CreateComputationResponse
  return ()

_computationToProto :: Computation -> PI.CreateComputationRequest
_computationToProto = undefined

_computationStatus :: (MonadLoggerIO m, MonadError e m) =>
  SparkSession -> ComputationID -> NodePath -> m PossibleNodeStatus
_computationStatus session compId npath = do
  let msg = (def :: PI.ComputationStatusRequest)
  msg' <- _sendBackend' session "ComputationStatus" msg
  _possibleNodeStatusFromProto msg'

_possibleNodeStatusFromProto :: (MonadError e m) => PC.BatchComputationResult -> m PossibleNodeStatus
_possibleNodeStatusFromProto = undefined

-- TODO: not sure how this works when trying to make a fix point: is it going to
-- blow up the 'stack'?
_computationMultiStatus ::
   -- The computation being run
  ComputationID ->
  -- The set of nodes that have been processed in this computation, and ended
  -- with a success.
  -- TODO: should we do all the nodes processed in this computation?
  HS.HashSet NodeId ->
  -- The list of nodes for which we have not had completion information so far.
  [(NodeId, NodePath, NodeShape)] ->
  SparkState [(NodeId, Try Cell)]
_computationMultiStatus _ _ [] = return []
_computationMultiStatus cid done l0 = do
  session <- get
  -- TODO: doing some hacks here to accomodate for some old code
  let l' = f <$> l0 where f (nid, np, ns) = (nid, np, ns, np)
  -- Find the nodes that still need processing (i.e. that have not previously
  -- finished with a success)
  let f (nid, _, _, _) = not $ HS.member nid done
  let needsProcessing = filter f l'
  -- Poll a bunch of nodes to try to get a status update.
  let statusl = _try (_computationStatus session cid) <$> needsProcessing :: [SparkState (NodeId, NodePath, NodeShape, PossibleNodeStatus)]
  status <- sequence statusl
  -- Update the state with the new data
  (updated, statusUpdate) <- returnPure $ updateCache cid status
  forM_ statusUpdate $ \(p, s) -> case s of
      NodeCacheSuccess ->
        logInfoN $ "_computationMultiStatus: " <> prettyNodePath p <> " finished"
      NodeCacheError ->
        logInfoN $ "_computationMultiStatus: " <> prettyNodePath p <> " finished (ERROR)"
      NodeCacheRunning ->
        logInfoN $ "_computationMultiStatus: " <> prettyNodePath p <> " running"
  -- Filter out the updated nodes, so that we do not ask for them again.
  let updatedNids = HS.union done (HS.fromList (fst <$> updated))
  let g (nid, _, _, _) = not $ HS.member nid updatedNids
  let stillNeedsProcessing = filter g needsProcessing
  -- Do not block uselessly if we have nothing else to do
  if null stillNeedsProcessing
  then return updated
  else do
    let delayMillis = confPollingIntervalMillis $ ssConf session
    _ <- liftIO $ threadDelay (delayMillis * 1000)
    -- TODO: this chaining is certainly not tail-recursive
    -- How much of a memory leak is it?
    let stillNeedsProcessing' = f' <$> stillNeedsProcessing where f' (nid, np, ns, _) = (nid, np, ns)
    reminder <- _computationMultiStatus cid updatedNids stillNeedsProcessing'
    return $ updated ++ reminder

_try :: (Monad m) => (y -> m z) -> (x, x', x'', y) -> m (x, x', x'', z)
_try f (x, x', x'', y) = f y <&> \z -> (x, x', x'', z)

_computationStats :: (MonadLoggerIO m, MonadError e m) =>
  SparkSession -> ComputationID -> m BatchComputationResult
_computationStats session compId = do
  let msg = (def :: PI.ComputationStatusRequest)
  msg' <- _sendBackend' session "ComputationStatus" msg
  _batchComputationResultFromProto msg'

_batchComputationResultFromProto :: (MonadError e m) => PC.BatchComputationResult -> m BatchComputationResult
_batchComputationResultFromProto = undefined

_waitSingleComputation :: (MonadLoggerIO m, MonadError e m) =>
  SparkSession -> Computation -> NodePath -> m FinalResult
_waitSingleComputation session comp npath =
  let
    extract :: PossibleNodeStatus -> Maybe FinalResult
    extract (NodeFinishedSuccess (Just s) _) = Just $ Right s
    extract (NodeFinishedFailure f) = Just $ Left f
    extract _ = Nothing
    getStatus = _computationStatus session (cId comp) npath
    i = confPollingIntervalMillis $ ssConf session
  in
    _pollMonad getStatus i extract
