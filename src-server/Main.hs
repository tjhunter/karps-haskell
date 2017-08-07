{-# LANGUAGE OverloadedStrings #-}
module Main where

import Web.Scotty
import Network.Wai.Middleware.RequestLogger
import Control.Monad.IO.Class
import qualified Data.Text as T
import Data.Default


import Spark.Proto.ApiInternal.PerformGraphTransform(PerformGraphTransform)
import Spark.Proto.ApiInternal.GraphTransformResponse(GraphTransformResponse)
import Spark.Server.StructureParsing(parseInput, protoResponse)
import Spark.Server.Transform(transform)
import Spark.Core.Try(Try)

mainProcessing :: PerformGraphTransform -> GraphTransformResponse
mainProcessing item =
  let res = do
        parsed <- parseInput item
        let opt = transform parsed
        protoResponse opt
  in case res of
    Right x -> x
    Left err -> error (show err)

main :: IO ()
main = do
  logger <- liftIO $ mkRequestLogger def { outputFormat = Apache FromHeader }
  scotty 1234 $ do
      get "/alive" $ do
          text "yep!"
      post "/perform_transform" $ (do
        item <- jsonData :: ActionM PerformGraphTransform
        json (mainProcessing item)) `rescue` (\msg -> text msg)
