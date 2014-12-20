package main

import (
  "fmt"
  "os"
  "os/exec"
  "syscall"
  "io/ioutil"
  "strings"
  "path/filepath"
  "unicode/utf16"
  "unsafe"
)

const pathSep = string(os.PathSeparator)

func main() {
  // Prerequisites
  var prefix string
  
  // No reason to use a PREFIX environment variable here.
  prefix, err := getNoDistPrefix()
  if err != nil {
    fmt.Println("Error locating NODIST_PREFIX: ", err)
    os.Exit(1)
  }

  // Determine version
  var version string = ""
  if v := os.Getenv("NODE_VERSION"); v != "" {
    version = v
    //fmt.Println("NODE_VERSION found:'", version, "'")
  } else if v = os.Getenv("NODIST_VERSION"); v != "" {
    version = v
    //fmt.Println("NODIST_VERSION found:'", version, "'")
  } else if v, _, err := getLocalVersion(); err == nil && strings.Trim(string(v), " \r\n") != "" {
    version = string(v)
    //fmt.Println("Local file found:'", version, "' @ ", localFile)
  } else if v, err := ioutil.ReadFile(filepath.Join(prefix, ".node-version")); err == nil {
    version = string(v)
    //fmt.Println("Global file found:'", version, "'")
  }

  version = strings.Trim(version, "v \r\n")
  if version == "" {
    fmt.Println("Sorry, there's a problem with nodist. Couldn't decide which node version to use. Please set a version.")
    os.Exit(41)
  }
  
  
  // Determine architecture
  // TODO: Technically, branch is called "no-envvars". Maybe get rid of this?
  x64 := false
  if wantX64 := os.Getenv("NODIST_X64"); wantX64 != "" {
    x64 = (wantX64 == "1")
  }

  // Set up binary path
  var path string
  var nodebin string

  path = filepath.Join(prefix, "v")
  if x64 {
    path += "-x64"
  }
  
  path = filepath.Join(path, version)
  nodebin = filepath.Join(path, "node.exe")
  
  // Get args
  var nodeargs []string
  if a, err := ioutil.ReadFile(filepath.Join(path, "args")); err == nil && len(a) != 0 {
    argsFile := strings.Split(string(a), " ")
    nodeargs = append(nodeargs, argsFile...)
  }
  
  nodeargs = append(nodeargs, os.Args[1:]...)
  
  // Run node!
  cmd := exec.Command(nodebin, nodeargs...)
  cmd.Stdout = os.Stdout
  cmd.Stderr = os.Stderr
  cmd.Stdin = os.Stdin
  err = cmd.Run()
  
  if err != nil {
    exitError, isExitError := err.(*(exec.ExitError))
    if isExitError {
      // You know it. Black Magic...
      os.Exit(exitError.Sys().(syscall.WaitStatus).ExitStatus())
    } else {
      fmt.Println("Sorry, there's a problem with nodist.")
      fmt.Println("Error: ", err)
      os.Exit(42)
    }
  }
}

func getLocalVersion() (version string, file string, error error) {
  dir, err := os.Getwd()
  
  if err != nil {
    error = err
    return
  }
  
  dirSlice := strings.Split(dir, pathSep) // D:\Programme\nodist => [D:, Programme, nodist]
  
  for len(dirSlice) != 1 {
    dir = strings.Join(dirSlice, pathSep)
        file = filepath.Join(dir, ".node-version")
    v, err := ioutil.ReadFile(file);
    
    if err == nil {
      version = string(v)
      return
    }

    if !os.IsNotExist(err) {
      error = err // some other error.. bad luck.
      return
    }
    
    // `$ cd ..`
    dirSlice = dirSlice[:len(dirSlice)-1] // pop the last dir
  }
  
  version = ""
  return
}

var (
    kernel                = syscall.MustLoadDLL("kernel32.dll")
    getModuleFileNameProc = kernel.MustFindProc("GetModuleFileNameW")
)

func getNoDistPrefix() (string, error) {
    folder, err := getExeFolder()
        if err != nil {
        return "", err
    }
    return filepath.Dir(folder), nil
}

func getExeFolder() (string, error) {
    exe, err := getExeFile()
    if err != nil {
        return "", err
    }
    return filepath.Dir(exe), nil
}

func getExeFile() (string, error) {
    exe, err := getModuleFileName()
    return filepath.Clean(exe), err
}

func getModuleFileName() (string, error) {
    var n uint32
    b := make([]uint16, syscall.MAX_PATH)
    size := uint32(len(b))

    r0, _, e1 := getModuleFileNameProc.Call(0, uintptr(unsafe.Pointer(&b[0])), uintptr(size))
    n = uint32(r0)
    if n == 0 {
        return "", e1
    }
    return string(utf16.Decode(b[0:n])), nil
}
