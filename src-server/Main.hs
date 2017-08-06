{-# LANGUAGE OverloadedStrings #-}
module Main where

import Web.Scotty
import qualified Data.Text as T

server :: ScottyM ()
server = do
    get "/alive" $ do
        text "yep!"
    post "/perform_transform" $ do
      json ("{}" :: T.Text)

main :: IO ()
main = do
    let x = undefined :: Int
    scotty 1234 server
