import os
import secrets
from urllib.parse import urlencode
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv
from flask import Flask, redirect, url_for, render_template, flash, session, \
    current_app, request, abort
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, logout_user,\
    current_user
import requests
from forms import *
load_dotenv()

app = Flask(__name__)
app.config['SECRET_KEY'] = 'top secret!'
app.config["REDIRECT_URL"]= os.environ.get("REDIRECT_URL","https://d2jveeqgia8fbm.cloudfront.net/callback")
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get("SQLALCHEMY_DATABASE_URI","mysql+pymysql://root@mariadb:3306/school_database")


app.config['OAUTH2_PROVIDERS'] = {
    # Google OAuth 2.0 documentation:
    # https://developers.google.com/identity/protocols/oauth2/web-server#httprest
    'microsoft': {
        'client_id': os.environ.get('MICRO_CLIENT_ID'),
        'client_secret': os.environ.get('MICRO_CLIENT_SECRET'),
        'authorize_url': 'https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize',
        'token_url': 'https://login.microsoftonline.com/organizations/oauth2/v2.0/token',
        'userinfo': {
            'url': 'https://graph.microsoft.com/oidc/userinfo',
            'email': lambda json: json['email'],
        },
        'scopes': ['https://graph.microsoft.com/email'],
    },

    # GitHub OAuth 2.0 documentation:
    # https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps
}

db = SQLAlchemy(app)
login = LoginManager(app)
login.login_view = 'index'





@login.user_loader
def load_user(id):
    return db.session.get(MdlUser, int(id))


@app.route('/', methods=['GET', 'POST'])
def index():
    form = PostForm()
    if form.validate_on_submit():
        post = Post(title=form.title.data, body=form.body.data, author=current_user)
        db.session.add(post)
        db.session.commit()
        flash('Your post is now live!', 'success')
        return redirect(url_for('index'))
    posts = Post.query.all()
    
    if current_user.is_authenticated:
        return render_template('index.html', posts=posts, form=form)
    else:
        return render_template('index.html')
@app.route('/logout')
def logout():
    logout_user()
    flash('You have been logged out.')
    return redirect(url_for('index'))


@app.route('/authorize/<provider>')
def oauth2_authorize(provider):
    print("=======first======")
    print(f"{app.config['REDIRECT_URL']}/{provider}")
    if not current_user.is_anonymous:
        return redirect(url_for('index'))

    provider_data = current_app.config['OAUTH2_PROVIDERS'].get(provider)
    if provider_data is None:
        abort(404)

    # generate a random db.String for the state parameter
    session['oauth2_state'] = secrets.token_urlsafe(16)

    # create a query db.String with all the OAuth2 parameters
    qs = urlencode({
        'client_id': provider_data['client_id'],
        'redirect_uri': f"{app.config['REDIRECT_URL']}/{provider}",
        'response_type': 'code',
        'scope': ' '.join(provider_data['scopes']),
        'state': session['oauth2_state'],
    })

    # redirect the user to the OAuth2 provider authorization URL
    return redirect(provider_data['authorize_url'] + '?' + qs)


@app.route('/callback/<provider>')
def oauth2_callback(provider):
    print(request.headers)
    print(request.__dict__)
    if not current_user.is_anonymous:
        return redirect(url_for('index'))

    provider_data = current_app.config['OAUTH2_PROVIDERS'].get(provider)
    if provider_data is None:
        abort(404)

    # if there was an authentication error, flash the error messages and exit
    if 'error' in request.args:
        for k, v in request.args.items():
            if k.startswith('error'):
                flash(f'{k}: {v}')
        return redirect(url_for('index'))

    # make sure that the state parameter matches the one we created in the
    # authorization request
    if request.args['state'] != session.get('oauth2_state'):
        abort(401)

    # make sure that the authorization code is present
    if 'code' not in request.args:
        abort(401)

    # exchange the authorization code for an access token
    response = requests.post(provider_data['token_url'], data={
        'client_id': provider_data['client_id'],
        'client_secret': provider_data['client_secret'],
        'code': request.args['code'],
        'grant_type': 'authorization_code',
        'redirect_uri': f"{app.config['REDIRECT_URL']}/{provider}",
    }, headers={'Accept': 'application/json'})
    if response.status_code != 200:
        abort(401)
    oauth2_token = response.json().get('access_token')
    if not oauth2_token:
        abort(401)

    # use the access token to get the user's email address
    response = requests.get(provider_data['userinfo']['url'], headers={
        'Authorization': 'Bearer ' + oauth2_token,
        'Accept': 'application/json',
    })
    if response.status_code != 200:
        abort(401)
    print(response.json())
    email = provider_data['userinfo']['email'](response.json())

    # find or create the user in the database
    user = db.session.scalar(db.select(MdlUser).where(MdlUser.email == email))
    if user is None:
        user = MdlUser(email=email, username=email.split('@')[0])
        db.session.add(user)
        db.session.commit()

    # log the user in
    login_user(user)
    return redirect(url_for('index'))




if __name__ == '__main__':
    app.run()
    
    
    
from sqlalchemy.dialects.mysql import MEDIUMINT, TINYINT,BIGINT,LONGTEXT

class Post(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.Text)
    body = db.Column(db.Text)
    created_at = db.Column(db.DateTime, index=True, default=datetime.utcnow)
    edited_at = db.Column(db.DateTime, nullable=True)
    user_id = db.Column(BIGINT(20), db.ForeignKey('mdl_user.id'))

class MdlUser(UserMixin, db.Model):
    __tablename__ = 'mdl_user'
    __table_args__ = (
        db.Index('mdl_user_mneuse_uix', 'mnethostid', 'username', unique=True),
        {'comment': 'One record for each person'}
    )

    id = db.Column(BIGINT(20), primary_key=True)
    posts = db.relationship('Post', backref='author', lazy='dynamic')
    auth = db.Column(db.String(20), nullable=False, index=True, server_default=db.text("'manual'"))
    confirmed = db.Column(TINYINT(1), nullable=False, index=True, server_default=db.text("0"))
    policyagreed = db.Column(TINYINT(1), nullable=False, server_default=db.text("0"))
    deleted = db.Column(TINYINT(1), nullable=False, index=True, server_default=db.text("0"))
    suspended = db.Column(TINYINT(1), nullable=False, server_default=db.text("0"))
    mnethostid = db.Column(BIGINT(20), nullable=False, server_default=db.text("0"))
    username = db.Column(db.String(100), nullable=False, server_default=db.text("''"))
    password = db.Column(db.String(255), nullable=False, server_default=db.text("''"))
    idnumber = db.Column(db.String(255), nullable=False, index=True, server_default=db.text("''"))
    firstname = db.Column(db.String(100), nullable=False, index=True, server_default=db.text("''"))
    lastname = db.Column(db.String(100), nullable=False, index=True, server_default=db.text("''"))
    email = db.Column(db.String(100), nullable=False, index=True, server_default=db.text("''"))
    emailstop = db.Column(TINYINT(1), nullable=False, server_default=db.text("0"))
    phone1 = db.Column(db.String(20), nullable=False, server_default=db.text("''"))
    phone2 = db.Column(db.String(20), nullable=False, server_default=db.text("''"))
    institution = db.Column(db.String(255), nullable=False, server_default=db.text("''"))
    department = db.Column(db.String(255), nullable=False, server_default=db.text("''"))
    address = db.Column(db.String(255), nullable=False, server_default=db.text("''"))
    city = db.Column(db.String(120), nullable=False, index=True, server_default=db.text("''"))
    country = db.Column(db.String(2), nullable=False, index=True, server_default=db.text("''"))
    lang = db.Column(db.String(30), nullable=False, server_default=db.text("'en'"))
    calendartype = db.Column(db.String(30), nullable=False, server_default=db.text("'gregorian'"))
    theme = db.Column(db.String(50), nullable=False, server_default=db.text("''"))
    timezone = db.Column(db.String(100), nullable=False, server_default=db.text("'99'"))
    firstaccess = db.Column(BIGINT(20), nullable=False, server_default=db.text("0"))
    lastaccess = db.Column(BIGINT(20), nullable=False, index=True, server_default=db.text("0"))
    lastlogin = db.Column(BIGINT(20), nullable=False, server_default=db.text("0"))
    currentlogin = db.Column(BIGINT(20), nullable=False, server_default=db.text("0"))
    lastip = db.Column(db.String(45), nullable=False, server_default=db.text("''"))
    secret = db.Column(db.String(15), nullable=False, server_default=db.text("''"))
    picture = db.Column(BIGINT(20), nullable=False, server_default=db.text("0"))
    description = db.Column(LONGTEXT)
    descriptionformat = db.Column(TINYINT(4), nullable=False, server_default=db.text("1"))
    mailformat = db.Column(TINYINT(1), nullable=False, server_default=db.text("1"))
    maildigest = db.Column(TINYINT(1), nullable=False, server_default=db.text("0"))
    maildisplay = db.Column(TINYINT(4), nullable=False, server_default=db.text("2"))
    autosubscribe = db.Column(TINYINT(1), nullable=False, server_default=db.text("1"))
    trackforums = db.Column(TINYINT(1), nullable=False, server_default=db.text("0"))
    timecreated = db.Column(BIGINT(20), nullable=False, server_default=db.text("0"))
    timemodified = db.Column(BIGINT(20), nullable=False, server_default=db.text("0"))
    trustbitmask = db.Column(BIGINT(20), nullable=False, server_default=db.text("0"))
    imagealt = db.Column(db.String(255))
    lastnamephonetic = db.Column(db.String(255), index=True)
    firstnamephonetic = db.Column(db.String(255), index=True)
    middlename = db.Column(db.String(255), index=True)
    alternatename = db.Column(db.String(255), index=True)
    moodlenetprofile = db.Column(db.String(255))
    
    
with app.app_context():
    db.create_all()