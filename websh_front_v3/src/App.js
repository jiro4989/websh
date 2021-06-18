import './App.css';
import { Terminal } from 'xterm';
import {useEffect} from 'react';

function App() {
  const term = new Terminal()

  useEffect(() => {
    const termElem = document.getElementById("terminal")
    term.open(termElem)
    term.writeln("Welcome to websh.")
    term.writeln("This is a web shellgei execution environment.")
    term.writeln("Type your shellgei.")
    term.writeln("")
    term.writeln("")
    term.writeln("$ echo sushi")
    term.writeln("sushi")
  })

  return (
    <div className="App">
      <div id="terminal"></div>
    </div>
  );
}

export default App;
