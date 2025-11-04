import React from 'react';
import logo from './logo.svg';
import './App.css';
import EasyBet from './components/EasyBet';

function App() {
  return (
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <EasyBet />
      </header>
    </div>
  );
}

export default App;
