
module Config (clients, fromAddress, emailAddresses, urlRoot) where

import Builder.Utils

fromAddress :: String
fromAddress = "cvs-ghc@haskell.org"

emailAddresses :: [String]
emailAddresses = ["igloo@earth.li"]

urlRoot :: String
urlRoot = "http://darcs.haskell.org/ghcBuilder/"

buildSteps :: [BuildStep]
buildSteps = [BuildStep {
                  bs_name = "Test build step",
                  bs_subdir = ".",
                  bs_prog = "/bin/mkdir",
                  bs_args = ["build"]
              },
              BuildStep {
                  bs_name = "Second test build step",
                  bs_subdir = "build",
                  bs_prog = "/bin/echo",
                  bs_args = ["argx1", "argx2", "argx3"]
              },
              BuildStep {
                  bs_name = "Mem test build step",
                  bs_subdir = "build",
                  bs_prog = "/usr/bin/perl",
                  bs_args = ["-e", "$x = 'a'x102476800"] -- 100M
              },
              BuildStep {
                  bs_name = "Last test build step",
                  bs_subdir = "build",
                  bs_prog = "/bin/pwd",
                  bs_args = []
              }]

clients :: [(String, UserInfo)]
clients = [("foo",
            mkUserInfo "mypass"
                       "UTC"
                       (Timed (mkTime 2 0))
                       buildSteps),
           ("bar",
            mkUserInfo "mypass"
                       "UTC"
                       Continuous
                       buildSteps),
           ("ghcBuilder",
            mkUserInfo "mypass"
                       "UTC"
                       (Timed (mkTime 13 55))
                       ghcBuildSteps)
          ]

darcsRepo :: String
darcsRepo = "/home/ian/ghc/darcs/ghc"

ghcBuildSteps :: [BuildStep]
ghcBuildSteps =
    [BuildStep {
         bs_name = "darcs checkout",
         bs_subdir = ".",
         bs_prog = "darcs",
         bs_args = ["get", "--partial", darcsRepo, "build"]
     },
     BuildStep {
         bs_name = "create mk/build.mk",
         bs_subdir = "build",
         bs_prog = "/bin/sh",
         bs_args = let ls = ["HADDOCK_DOCS=YES", "LATEX_DOCS=YES"]
                       str = concatMap (++ "\n") ls
                   in ["-c", "printf '" ++ str ++ "' | tee mk/build.mk"]
     },
     BuildStep {
         bs_name = "make darcs-all executable",
         bs_subdir = "build",
         bs_prog = "chmod",
         bs_args = ["+x", "darcs-all"]
     },
     BuildStep {
         bs_name = "get subrepos",
         bs_subdir = "build",
         bs_prog = "./darcs-all",
         bs_args = ["--testsuite", "get"]
     },
     BuildStep {
         bs_name = "repo versions",
         bs_subdir = "build",
         bs_prog = "./darcs-all",
         bs_args = ["changes", "--last=1"]
     },
     BuildStep {
         bs_name = "setting version date",
         bs_subdir = "build",
         bs_prog = "sh",
         bs_args = ["-c", "date +%Y%m%d | tee VERSION_DATE"]
     },
     BuildStep {
         bs_name = "booting",
         bs_subdir = "build",
         bs_prog = "sh",
         bs_args = ["boot"]
     },
     BuildStep {
         bs_name = "configuring",
         bs_subdir = "build",
         bs_prog = "./configure",
         bs_args = []
     },
     BuildStep {
         bs_name = "compiling",
         bs_subdir = "build",
         bs_prog = "make",
         bs_args = []
     },
     BuildStep {
         bs_name = "making bindist",
         bs_subdir = "build",
         bs_prog = "make",
         bs_args = ["binary-dist"]
     },
     BuildStep {
         bs_name = "testing bindist",
         bs_subdir = "build",
         bs_prog = "make",
         bs_args = ["-C", "bindisttest"]
     },
     BuildStep {
         bs_name = "testing",
         bs_subdir = "build",
         bs_prog = "make",
         bs_args = ["-C", "testsuite/tests/ghc-regress", "BINDIST=YES"]
     }]

