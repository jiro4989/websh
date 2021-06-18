import './App.css'
import React, { useState } from 'react'

function newUniqueId() {
  const date = new Date().getTime().toString(16)
  const rand = Math.floor(1000*Math.random()).toString(16)
  return date + rand
}

function newHistory(shellgei) {
  const id = newUniqueId()
  const history = {
    id: id,
    shellgei: shellgei,
    stdout: "hello world",
    stderr: "no error",
  }
  return history
}

function App() {
  const [shellgei, setShellgei] = useState("")
  const [histories, setHistories] = useState([])

  const runShellgei = (shell) => {
    const history = newHistory(shell)
    setHistories([...histories, history])
    console.log(shell)
    console.log(histories)
  }

  const historyElems = histories
    .map((v) => <div key={v.id}>
      <div>
        <textarea className="shellgei-input" defaultValue={v.shellgei} />
      </div>
      <div>
        <section>
          <span className="stdout">STDOUT:</span>
          <textarea className="shellgei-input" defaultValue={v.stdout} />
        </section>
        <section>
          <span className="stderr">STDERR:</span>
          <textarea className="shellgei-input" defaultValue={v.stderr} />
        </section>
      </div>
    </div>)

  return (
    <div className="App">
      <div className="terminal-area">
        {historyElems}
        <div>
          <div>
            <textarea
              className="shellgei-input"
              onChange={(e) => setShellgei(e.target.value)}
              autoFocus
            />
          </div>
          <div>
            <button onClick={(e) => runShellgei(shellgei)}>Run</button>
            <button>Tweet</button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
