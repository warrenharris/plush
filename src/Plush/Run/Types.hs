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

module Plush.Run.Types (
    ExitCode, Args,
    success,
    exit, exitMsg,
    notSupported,

    FoundCommand(..),
    Annotation(..),

    Utility(..),
    emptyAnnotate, noArgsAnnotate,
    )
where

import Control.Monad.Error.Class
import qualified Data.Text as T

import Plush.Run.Posix
import Plush.Types.CommandSummary


type ExitCode = Int
type Args = [String]

success :: (Monad m) => m ExitCode
success = exit 0

exit :: (Monad m) => ExitCode -> m ExitCode
exit = return

exitMsg :: (PosixLike m) => ExitCode -> String -> m ExitCode
exitMsg e msg = do
    errStrLn msg `catchError` (\_ -> return ())
    exit e

notSupported :: (PosixLike m) => String -> m ExitCode
notSupported s = exitMsg 121 ("*** Not Supported: " ++ s)


-- | The result of searching for a command. See "Plush.Run.BuiltIns" for
-- descriptions of special, direct, and builtin commands.
data FoundCommand = SpecialCommand
                  | DirectCommand
                  | BuiltInCommand FilePath
                  | ExecutableCommand FilePath
                  | UnknownCommand


data Annotation = ExpandedTo String
                | FoundCommandAnno FoundCommand
                | CommandSummaryAnno CommandSummary
                | OptionAnno T.Text
                | UnusedAnno
    -- TODO: some of these should probably be Text rather than String


data Utility m = Utility
    { utilExecute  :: Args -> m ExitCode
    , utilAnnotate :: Args -> m [[Annotation]]
--  , utilComplete :: Args -> m Completion
    }

emptyAnnotate :: (Monad m) => Args -> m [[Annotation]]
emptyAnnotate _ = return []

noArgsAnnotate :: (Monad m) => Args -> m [[Annotation]]
noArgsAnnotate args = return $ map (const [UnusedAnno]) args
