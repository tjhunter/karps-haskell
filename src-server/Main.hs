{-# LANGUAGE OverloadedStrings #-}
module Main where

import Web.Scotty
import Network.Wai.Middleware.RequestLogger
import Control.Monad.IO.Class
import Data.Default
import Data.Text(pack)
import Data.ProtoLens.Encoding(decodeMessage, encodeMessage)
import qualified Data.ByteString.Lazy as LBS
import Lens.Family2 ((&), (.~))

import Spark.Server.Transform(transform)
import qualified Proto.Karps.Proto.ApiInternal as PAI


-- It should be a graph transform
serverFunction :: LBS.ByteString -> LBS.ByteString
serverFunction bs = LBS.fromStrict . encodeMessage $ x where
  x = case decodeMessage (LBS.toStrict bs) of
      Right pgt -> transform pgt
      Left txt -> msg where
        msg0 = def :: PAI.GraphTransformResponse
        am = (def :: PAI.AnalysisMessage) & PAI.content .~ pack txt
        msg = msg0 & PAI.messages .~ [am]

main :: IO ()
main = do
  _ <- liftIO $ mkRequestLogger def { outputFormat = Apache FromHeader }
  scotty 1234 $ do
      get "/alive" $ do
          text "yep!"
      post "/perform_transform" $ (do
        item <- body
        raw (serverFunction item)) `rescue` (\msg -> text msg)
