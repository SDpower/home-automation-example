import AppBar from 'material-ui/AppBar';
import FlatButton from 'material-ui/FlatButton';
import RaisedButton from 'material-ui/RaisedButton';
import { white } from 'material-ui/styles/colors';
import React from 'react';
import { Link } from 'react-router';
import cookie from 'react-cookie';

export default class LogoutView extends React.Component {
  componentWillMount() {
    cookie.remove('sid', { path: '/' });
  }

  render() {
    return (
      <div className="auth-page">
        <AppBar
          iconElementRight={
            <RaisedButton
              containerElement={<Link to="/login" />}
              label="login"
              secondary
            />
          }
          showMenuIconButton={false}
          style={{ background: white, boxShadow: 'none' }}
        />

      <main className="container container--small" style={{ textAlign: 'center' }}>
          <div className="logo-container">
            <img src="images/example_iot_company_logo_mark.svg" />
            <h1>Example</h1>
            <h4>IoT Company</h4>
          </div>

          <h2 style={{ textAlign: 'center' }}>Logout</h2>
          <p style={{ margin: '8px 0'}}>You've been signed out</p>
          <FlatButton
            containerElement={<Link to="/login" />}
            label="Login again"
            secondary
          />
        </main>
        <footer className="version">
          Version 1.0.4
        </footer>
      </div>
    );
  }
}
