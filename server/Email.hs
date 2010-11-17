
module Email where

import SendMail
import ServerMonad

import Builder.Command
import Builder.Config
import Builder.Files
import Builder.Utils

import Codec.MIME.String.Flatten
import Codec.MIME.String.Headers
import Control.Monad
import Data.Maybe
import System.Exit
import System.FilePath

sendEmails :: Config -> User -> BuildNum -> String -> IO ()
sendEmails config u bn url
 = do let fromAddress = config_fromAddress config
          emailAddresses = config_emailAddresses config
          buildsDir = baseDir </> "clients" </> u </> "builds"
          buildDir = buildsDir </> show bn
          stepsDir = buildDir </> "steps"
          root = Server (baseDir </> "clients") u
      bsns <- getSortedNumericDirectoryContents stepsDir
              `onDoesNotExist`
              return []
      steps <- mapM (mkStep root bn) bsns
      result <- readBuildResult root bn
      let (stepDescrs, maybeAttachments) = unzip steps
          buildResult = case result of
                        Success -> "Build succeeded"
                        Failure -> "Build failed"
                        Incomplete -> "Build incomplete"
          description = u ++ ", build " ++ show bn
          link = "Details: " ++ url
          bodyLines = [description,
                       "",
                       buildResult,
                       link,
                       ""]
                   ++ showTable [rPad, noPad]
                                stepDescrs
                   ++ ["",
                       buildResult,
                       link,
                       ""]
          subject = description ++ ", " ++ show result
          body = unlines bodyLines
      unless (null emailAddresses) $
          sendMail fromAddress emailAddresses subject
                   body Nothing
                   (catMaybes maybeAttachments)

mkStep :: Root -> BuildNum -> BuildStepNum -> IO ([String], Maybe Attachment)
mkStep root bn bsn
    = do stepName <- readBuildStepName root bn bsn
         ec <- readBuildStepExitcode root bn bsn
         case ec of
             ExitSuccess ->
                 return ([stepName, "Success"],
                         Nothing)
             ExitFailure n ->
                 do moutput <- getMaybeBuildStepOutput root bn bsn
                    let doLine x = case maybeReadSpace x of
                                   Nothing -> x
                                   Just (Stdout str) -> str
                                   Just (Stderr str) -> str
                        lastFew = case moutput of
                                  Nothing -> ""
                                  Just x ->
                                      unlines $ shrink30Lines $ map doLine
                                              $ lastN 30 $ lines x
                        -- XXX This is a hideous hack:
                        lastFew' = map toLatin1 lastFew
                        toLatin1 c
                         | c > '\xFF' = '?'
                         | otherwise  = c
                        contentType = ContentType "text" "plain"
                                          [Parameter "charset" "ISO-8859-1"]
                        attachment = (lastFew',
                                      "step." ++ stepName ++ ".txt",
                                      Just contentType)
                    return ([stepName, "Failure: " ++ show n],
                            Just attachment)

shrink30Lines :: [String] -> [String]
shrink30Lines xs = reverse $ shrink surplus allowances inputs
    where inputs = map (\str -> (str, length str)) $ reverse xs
          allowances = replicate 5 300 ++ replicate 10 200 ++ replicate 15 100
          surplus = getSurplus allowances $ map snd inputs

getSurplus :: [Int] -> [Int] -> Int
getSurplus allowances vals = sum $ zipWith f allowances (vals ++ repeat 0)
    where f allowance val = if allowance > val then allowance - val
                                               else 0

shrink :: Int -> [Int] -> [(String, Int)] -> [String]
shrink _ _ [] = []
shrink _ [] _ = error "Too many lines"
shrink surplus (allowance : as) ((str, len) : xs)
 | allowance >= len
    = str : shrink surplus as xs
 | maxAllowed >= len
    = str : shrink (maxAllowed - len) as xs
 | otherwise
    = let partial = take halfMaxAllowed1 str ++ " [...] " ++
                    reverse (take halfMaxAllowed2 (reverse str))
      in partial : shrink 0 as xs
 where maxAllowed = surplus + allowance
       halfMaxAllowed1 = maxAllowed `div` 2
       halfMaxAllowed2 = maxAllowed - halfMaxAllowed1

