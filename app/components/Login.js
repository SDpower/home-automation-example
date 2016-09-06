import AppBar from 'material-ui/AppBar';
import FlatButton from 'material-ui/FlatButton';
import FontIcon from 'material-ui/FontIcon';
import ActionAndroid from 'material-ui/svg-icons/action/android';
import LinearProgress from 'material-ui/LinearProgress';
import RaisedButton from 'material-ui/RaisedButton';
import TextField from 'material-ui/TextField';
import { white } from 'material-ui/styles/colors';
import React from 'react';
import { Link } from 'react-router';
import MessageBox from './MessageBox';
import Popout from 'react-popout';

const Login = ({ errorText, isAuthenticating, onSubmit }) => (
  <div className="auth-page">
    <AppBar
      iconElementRight={
        <RaisedButton
          containerElement={<Link to="/signup" />}
          label="Sign up"
          secondary
        />
      }
      showMenuIconButton={false}
      style={{ background: white, boxShadow: 'none' }}
    />

    <main className="container container--small">
      <div className="logo-container">
        <img src="images/example_iot_company_logo_mark.svg" />
        <h1>Example</h1>
        <h4>IoT Company</h4>
      </div>

      <h2 style={{ textAlign: 'center' }}>Login</h2>
      {errorText && <MessageBox error text={errorText} />}

      <form onSubmit={onSubmit}>
        <TextField
          autoFocus
          hintText="Email address"
          floatingLabelText="Email address"
          fullWidth
          name="email"
          required
          type="email"
        />
        <TextField
          hintText="Password"
          floatingLabelText="Password"
          fullWidth
          name="password"
          required
          type="password"
        />
        <RaisedButton
          disabled={isAuthenticating}
          fullWidth
          label="Login"
          primary
          style={{ marginTop: 16, width: '100%' }}
          type="submit"
        >
          {isAuthenticating && <LinearProgress />}
        </RaisedButton>
      </form>

      <FlatButton label="Forgot password?" primary style={{ width: '100%' }} />

      <h3 style={{ textAlign: 'center' }}>Login With</h3>
      <FlatButton
        label="Amazon"
        href="/social/handle/Amazon/loginurl"
      />
      <FlatButton
        label="Facebook"
        backgroundColor="#339cff"
        hoverColor="#b3daff"
        href="/social/handle/Facebook/loginurl"
      />
      <FlatButton
        label="Google"
        backgroundColor="#ff8566"
        hoverColor="#ffc2b3"
        href="/social/handle/Google/loginurl"
      />
      <FlatButton
        label="GitHub"
        backgroundColor="#70db70"
        hoverColor="#c1f0c1"
        href="/social/handle/GitHub/loginurl"
      />
    </main>
    <footer className="version">
      Version 1.0.4
    </footer>
  </div>
);

Login.propTypes = {
  errorText: React.PropTypes.string,
  isAuthenticating: React.PropTypes.bool,
  onSubmit: React.PropTypes.func.isRequired,
};

export default Login;
