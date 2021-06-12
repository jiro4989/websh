import './App.css';
import Terminal from 'terminal-in-react';

function App() {
  return (
    <div className="App"
         style={{
           display: "flex",
           justifyContent: "center",
           alignItems: "center",
           height: "100vh",
         }}>
      <Terminal
        color="green"
        backgroundColor="black"
        style={{ fontWeight: "bold", fontSize: "1em" }}
        msg="Welcome to websh. This is a web shellgei execution environment. Type your shellgei."
        commandPassThrough={ cmd => {} }
        />
    </div>
  );
}

export default App;
