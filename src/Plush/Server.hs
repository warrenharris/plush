{-
Copyright 2012 Google Inc. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-}

{-# LANGUAGE OverloadedStrings #-}

module Plush.Server (
    server,
    )
    where


import Control.Concurrent (forkIO)
import Control.Monad (replicateM, void)
import Data.Maybe (fromMaybe)
import qualified Data.Text as T
import Network.HTTP.Types
import qualified Network.Wai.Handler.Warp as Warp
import Network.Wai.Middleware.Route
import Network.Wai.Middleware.Static
import System.FilePath
import System.IO
import System.Posix (sleep)
import System.Random

import Plush.Job
import Plush.Parser
import Plush.Run
import Plush.Server.API
import Plush.Server.Utilities
import Plush.Utilities

-- | Run the plush web server. The supplied 'Runner' is used as the shell, and
-- an optional port can be supplied. This action does not complete until the
-- shell exits.
server :: Runner -> Maybe Int -> IO ()
server runner port = do
    (shellThread, origOut, origErr) <- startShell runner
    staticPath <- (</> "static") `fmap` getDataDir
    key <- genKey
    hPutStrLn origOut $ "Starting server, connect to: " ++ startUrl key
    case parseNextCommand (openCmd $ startUrl key) of
        Right (cl, _rest) -> void $ forkIO $ launchOpen shellThread cl
        Left errs -> hPutStrLn origErr errs
    Warp.run port' $ application shellThread key staticPath
  where
    port' = fromMaybe 29544 port
    genKey = replicateM 40 $ randomRIO ('a','z')
    startUrl key =  "http://localhost:" ++ show port' ++ "/index.html#" ++ key
    openCmd url = "xdg-open " ++ url ++ " 2>/dev/null || open " ++ url
    launchOpen st cl = sleep 1 >> submitJob st "opener" cl


application shellThread key staticPath = dispatch
    [ (rule methodPost "^/api/run", jsonKeyApp $ runApp shellThread)
    , (rule methodPost "^/api/poll", jsonKeyApp $ pollApp shellThread)
    , (rule methodPost "^/api/input", jsonKeyApp $ inputApp shellThread)
    , (rule methodPost "^/api/history", jsonKeyApp $ historyApp shellThread)
    ]
    staticApp
  where
    jsonKeyApp app = jsonApp $ keyedApp key app
    staticApp = (staticRoot (T.pack staticPath)) (respApp notFound)

